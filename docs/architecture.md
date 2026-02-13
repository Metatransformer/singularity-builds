# Architecture

## Overview

Singularity Engine is a serverless pipeline that turns tweets into deployed web applications.

## Components

### 1. Tweet Watcher (`aws/tweet-watcher/index.mjs`)
- **Trigger:** EventBridge rule, every 2 minutes
- **Input:** X API search for replies to a specific tweet
- **Process:** Sanitize → deduplicate → rate limit → invoke Code Runner
- **State:** Tracks last processed tweet ID in DynamoDB (`_system` namespace)

### 2. Code Runner (`aws/code-runner/run.mjs`)
- **Trigger:** Invoked by Tweet Watcher
- **Input:** Sanitized build request + app ID
- **Process:** Send to Claude with system prompt → extract HTML → security scan
- **Output:** Single-file HTML application
- **Alternative:** Can run in Docker for extra isolation

### 3. Deployer (`aws/deployer/index.mjs`)
- **Trigger:** Invoked by Tweet Watcher (after Code Runner succeeds)
- **Input:** Generated HTML + metadata
- **Process:** Push to GitHub Pages → log build → queue reply
- **Output:** Live URL at `https://your-org.github.io/builds/apps/{app-id}/`

### 4. Reply Poller (`poller/poll-and-reply.mjs`)
- **Trigger:** Runs locally, polls DynamoDB every 45s
- **Input:** Pending replies from `_reply_queue` namespace
- **Process:** Open tweet in OpenClaw browser → compose reply → send
- **Why local?** X API doesn't allow tweets from Lambda easily; browser automation is more reliable

### 5. SingularityDB (`db/`)
- **API:** Lambda behind API Gateway v2
- **Storage:** DynamoDB with namespace + key composite key
- **Client:** Zero-dependency browser JavaScript class
- **Namespacing:** Each app gets its own namespace, preventing cross-app access

## Data Flow

```
X API → Tweet Watcher → Code Runner → Deployer → GitHub Pages
                                          ↓
                                     DynamoDB (_reply_queue)
                                          ↓
                                    Reply Poller → X (via browser)
```

## DynamoDB Schema

| Namespace | Purpose |
|-----------|---------|
| `_system` | Internal state (last processed tweet, etc.) |
| `_builds` | Build log (app ID → metadata) |
| `_reply_queue` | Pending tweet replies |
| `_showcase` | Public gallery entries |
| `{app-id}` | Per-app user data |

Partition key: `ns` (namespace), Sort key: `key`.

## Security Layers

1. **Input:** Regex-based injection detection + content blocklist
2. **Generation:** Constrained system prompt with strict rules
3. **Output:** Pattern scanning for dangerous JavaScript
4. **Runtime:** Static HTML only, no server-side execution
5. **Data:** Namespace isolation in DynamoDB
