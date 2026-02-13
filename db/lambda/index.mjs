import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  DeleteCommand,
  QueryCommand,
} from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({});
const ddb = DynamoDBDocumentClient.from(client);
const TABLE = process.env.TABLE_NAME || "singularity-db";

const headers = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type",
};

const respond = (statusCode, body) => ({
  statusCode,
  headers,
  body: JSON.stringify(body),
});

export const handler = async (event) => {
  // Handle CORS preflight
  if (event.requestContext?.http?.method === "OPTIONS") {
    return respond(200, { ok: true });
  }

  const method = event.requestContext?.http?.method || event.httpMethod;
  const path = event.rawPath || event.path || "";
  
  // Parse path: /api/data/{namespace}/{key}
  //         or: /api/data/{namespace}
  const parts = path.replace(/^\/api\/data\/?/, "").split("/").filter(Boolean);
  const namespace = parts[0];
  const key = parts[1];

  if (!namespace) {
    return respond(400, { error: "namespace required", usage: "/api/data/{namespace}/{key}" });
  }

  try {
    switch (method) {
      case "GET": {
        if (key) {
          // Get single item
          const result = await ddb.send(new GetCommand({
            TableName: TABLE,
            Key: { ns: namespace, key },
          }));
          if (!result.Item) return respond(404, { error: "not found" });
          return respond(200, { namespace, key, value: result.Item.value, updatedAt: result.Item.updatedAt });
        } else {
          // List all keys in namespace
          const result = await ddb.send(new QueryCommand({
            TableName: TABLE,
            KeyConditionExpression: "ns = :ns",
            ExpressionAttributeValues: { ":ns": namespace },
            ProjectionExpression: "#k, updatedAt",
            ExpressionAttributeNames: { "#k": "key" },
          }));
          return respond(200, { namespace, keys: result.Items.map(i => ({ key: i.key, updatedAt: i.updatedAt })), count: result.Count });
        }
      }

      case "PUT": {
        if (!key) return respond(400, { error: "key required for PUT" });
        const body = JSON.parse(event.body || "{}");
        await ddb.send(new PutCommand({
          TableName: TABLE,
          Item: {
            ns: namespace,
            key,
            value: body.value !== undefined ? body.value : body,
            updatedAt: new Date().toISOString(),
          },
        }));
        return respond(200, { ok: true, namespace, key });
      }

      case "DELETE": {
        if (!key) return respond(400, { error: "key required for DELETE" });
        await ddb.send(new DeleteCommand({
          TableName: TABLE,
          Key: { ns: namespace, key },
        }));
        return respond(200, { ok: true, deleted: { namespace, key } });
      }

      default:
        return respond(405, { error: `method ${method} not allowed` });
    }
  } catch (err) {
    console.error(err);
    return respond(500, { error: err.message });
  }
};
