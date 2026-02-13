#!/bin/bash
set -e

REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${TABLE_NAME:-singularity-db}"
FUNCTION_NAME="singularity-db-api"
ROLE_NAME="singularity-db-lambda-role"
API_NAME="singularity-db-api"

echo "🚀 Deploying Singularity DB to AWS..."

# 1. Create DynamoDB table
echo "📦 Creating DynamoDB table..."
aws dynamodb create-table \
  --table-name "$TABLE_NAME" \
  --attribute-definitions \
    AttributeName=ns,AttributeType=S \
    AttributeName=key,AttributeType=S \
  --key-schema \
    AttributeName=ns,KeyType=HASH \
    AttributeName=key,KeyType=RANGE \
  --billing-mode PAY_PER_REQUEST \
  --region "$REGION" \
  2>/dev/null && echo "  ✅ Table created" || echo "  ⏭️  Table already exists"

# Wait for table to be active
echo "  ⏳ Waiting for table to be active..."
aws dynamodb wait table-exists --table-name "$TABLE_NAME" --region "$REGION"
echo "  ✅ Table active"

# 2. Create IAM role for Lambda
echo "🔐 Creating IAM role..."
TRUST_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}'

ROLE_ARN=$(aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --query 'Role.Arn' --output text \
  2>/dev/null) || ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

echo "  ✅ Role: $ROLE_ARN"

# Attach policies
aws iam attach-role-policy --role-name "$ROLE_NAME" \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

# Inline policy for DynamoDB access
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DDB_POLICY='{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query"
    ],
    "Resource": "arn:aws:dynamodb:'$REGION':'$ACCOUNT_ID':table/'$TABLE_NAME'"
  }]
}'

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "singularity-db-dynamodb" \
  --policy-document "$DDB_POLICY"

echo "  ✅ Policies attached"

# 3. Package and deploy Lambda
echo "📦 Packaging Lambda..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/lambda"
npm install --production 2>/dev/null
zip -r ../function.zip . -x "*.git*" > /dev/null
cd "$SCRIPT_DIR"

# Wait for IAM role propagation
echo "  ⏳ Waiting for IAM role propagation (10s)..."
sleep 10

echo "🔧 Deploying Lambda function..."
FUNCTION_ARN=$(aws lambda create-function \
  --function-name "$FUNCTION_NAME" \
  --runtime nodejs20.x \
  --handler index.handler \
  --role "$ROLE_ARN" \
  --zip-file fileb://function.zip \
  --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
  --timeout 10 \
  --memory-size 256 \
  --region "$REGION" \
  --query 'FunctionArn' --output text \
  2>/dev/null) || {
    echo "  ⏭️  Function exists, updating..."
    FUNCTION_ARN=$(aws lambda update-function-code \
      --function-name "$FUNCTION_NAME" \
      --zip-file fileb://function.zip \
      --region "$REGION" \
      --query 'FunctionArn' --output text)
    aws lambda update-function-configuration \
      --function-name "$FUNCTION_NAME" \
      --environment "Variables={TABLE_NAME=$TABLE_NAME}" \
      --region "$REGION" > /dev/null 2>&1 || true
  }

echo "  ✅ Lambda: $FUNCTION_ARN"

# 4. Create HTTP API (API Gateway v2)
echo "🌐 Creating API Gateway..."
API_ID=$(aws apigatewayv2 create-api \
  --name "$API_NAME" \
  --protocol-type HTTP \
  --cors-configuration AllowOrigins='*',AllowMethods='GET,PUT,DELETE,OPTIONS',AllowHeaders='Content-Type' \
  --region "$REGION" \
  --query 'ApiId' --output text \
  2>/dev/null) || {
    # Get existing API
    API_ID=$(aws apigatewayv2 get-apis --region "$REGION" \
      --query "Items[?Name=='$API_NAME'].ApiId" --output text)
  }

echo "  ✅ API ID: $API_ID"

# Create Lambda integration
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id "$API_ID" \
  --integration-type AWS_PROXY \
  --integration-uri "$FUNCTION_ARN" \
  --payload-format-version "2.0" \
  --region "$REGION" \
  --query 'IntegrationId' --output text)

echo "  ✅ Integration: $INTEGRATION_ID"

# Create catch-all route
aws apigatewayv2 create-route \
  --api-id "$API_ID" \
  --route-key 'ANY /api/data/{proxy+}' \
  --target "integrations/$INTEGRATION_ID" \
  --region "$REGION" > /dev/null

# Create default stage with auto-deploy
aws apigatewayv2 create-stage \
  --api-id "$API_ID" \
  --stage-name '$default' \
  --auto-deploy \
  --region "$REGION" > /dev/null 2>&1 || true

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
  --function-name "$FUNCTION_NAME" \
  --statement-id "apigateway-invoke" \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*" \
  --region "$REGION" 2>/dev/null || true

API_URL="https://$API_ID.execute-api.$REGION.amazonaws.com/api/data"

echo ""
echo "============================================"
echo "🎉 Singularity DB deployed!"
echo "============================================"
echo ""
echo "API URL: $API_URL"
echo ""
echo "Usage:"
echo "  PUT  $API_URL/{namespace}/{key}  → store JSON"
echo "  GET  $API_URL/{namespace}/{key}  → read JSON"
echo "  GET  $API_URL/{namespace}        → list keys"
echo "  DELETE $API_URL/{namespace}/{key} → delete"
echo ""
echo "Test it:"
echo "  curl -X PUT '$API_URL/test/hello' -d '{\"value\": \"world\"}'"
echo "  curl '$API_URL/test/hello'"
echo ""
echo "⚠️  Add this URL to your .env as SINGULARITY_DB_URL=$API_URL"

# Cleanup
rm -f function.zip
echo "✅ Done!"
