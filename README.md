# 🦀 Singularity Engine

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Node.js](https://img.shields.io/badge/node-%3E%3D20-green.svg)](https://nodejs.org)
[![Built with Claude](https://img.shields.io/badge/built%20with-Claude-blueviolet)](https://anthropic.com)

**Autonomous tweet-to-app pipeline.** Someone tweets a request → AI builds it → deploys to GitHub Pages → replies with a live link. All in ~60 seconds.

🌐 **[See it in action →](https://metatransformer.com)**  
🎨 **[Live app gallery →](https://metatransformer.github.io/singularity-builds/)**

---

## How It Works

```
Tweet: "@you build me a pomodoro timer"
                    │
                    ▼
         ┌──────────────────┐
         │  Tweet Watcher   │  (Lambda + EventBridge, polls every 2 min)
         │  Sanitize input  │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │   Code Runner    │  (Lambda, Claude generates single-file HTML)
         │  Security scan   │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │    Deployer      │  (Lambda, pushes to GitHub Pages)
         │  Queue reply     │
         └────────┬─────────┘
                  │
                  ▼
         ┌──────────────────┐
         │  Reply Poller    │  (Local, replies via OpenClaw browser)
         └──────────────────┘
                  │
                  ▼
Reply: "built it. here's your pomodoro timer: https://you.github.io/builds/apps/timer/ 🦀"
```

## Architecture

The engine is three AWS Lambda functions + a local reply poller:

| Component | Runtime | Purpose |
|-----------|---------|---------|
| **Tweet Watcher** | Lambda (EventBridge, 2min) | Polls X API for replies, sanitizes, triggers builds |
| **Code Runner** | Lambda (or Docker) | Claude generates single-file HTML apps |
| **Deployer** | Lambda | Pushes HTML to GitHub Pages, queues reply |
| **Reply Poller** | Local Node.js | Polls DynamoDB queue, replies via OpenClaw browser |
| **SingularityDB** | Lambda + API Gateway + DynamoDB | Serverless key-value store for app persistence |

## Prerequisites

- **Node.js** ≥ 20
- **AWS Account** with CLI configured (`aws configure`)
- **X (Twitter) API** Bearer token (Basic tier, $100/mo — or use free search)
- **GitHub** Personal access token with `repo` scope
- **Anthropic API** key (for Claude)
- **[OpenClaw](https://openclaw.com)** (optional, for automated tweet replies)

## Quick Start

```bash
# 1. Clone
git clone https://github.com/Metatransformer/singularity-engine.git
cd singularity-engine

# 2. Interactive setup (writes .env)
npm run setup

# 3. Deploy SingularityDB (creates DynamoDB + API Gateway)
npm run deploy:db

# 4. Deploy the engine (3 Lambda functions + EventBridge)
npm run deploy

# 5. Post a tweet and reply to it with a build request!
```

### Dry Run

```bash
npm run deploy:dry-run
```

This prints what would be created without making any AWS changes.

## SingularityDB

Every generated app gets a persistent key-value store — no setup required.

```javascript
// Drop into any HTML file
const db = new SingularityDB("my-app");
await db.set("scores/alice", { score: 42 });
const data = await db.get("scores/alice");  // { score: 42 }
await db.list();                             // all keys
await db.delete("scores/alice");
```

The client is in [`db/client.js`](db/client.js). Deploy the backend with `npm run deploy:db`.

**API:**
- `GET /api/data/{namespace}/{key}` — read
- `PUT /api/data/{namespace}/{key}` — write (body: `{ "value": ... }`)
- `DELETE /api/data/{namespace}/{key}` — delete
- `GET /api/data/{namespace}` — list keys

Namespaced by app ID, so apps can't access each other's data.

## Security Model

The engine runs untrusted code requests from the internet. Here's how it stays safe:

### Input Sanitization
- **Prompt injection detection** — regex patterns catch "ignore previous instructions", system prompt extraction, etc.
- **Blocked content** — NSFW, weapons, malware, phishing attempts
- **Length limits** — 500 char max for build requests
- **HTML/tag stripping** — removes anything that looks like code injection

### Output Scanning
- **No `eval()`**, `Function()`, or dynamic code execution
- **No `require()`** or ES module imports
- **No `document.cookie`**, localStorage, or sessionStorage access
- **Fetch allowlist** — only SingularityDB API URLs permitted
- **No iframes**, `window.open`, or navigation

### Rate Limiting
- 2 builds per user per hour (configurable)
- Owner account exempt
- Cooldown between replies

### Infrastructure
- Lambda functions run in isolated AWS containers
- Docker option available for extra sandboxing
- DynamoDB namespacing prevents cross-app data access
- GitHub token has minimal `repo` scope

## Cost Breakdown

Running at moderate scale (~100 builds/day):

| Service | Monthly Cost |
|---------|-------------|
| **Lambda** (3 functions) | ~$1-5 |
| **DynamoDB** (on-demand) | ~$1-3 |
| **API Gateway** | ~$1 |
| **Claude API** (~100 builds × $0.01-0.05 each) | ~$1-5 |
| **X API** (Basic tier) | $100 |
| **GitHub Pages** | Free |
| **Total** | ~$105-115/mo |

The X API is the biggest cost. You can reduce this by using the free tier (limited search) or switching to a different trigger mechanism.

## Customization

### System Prompts
Edit [`shared/prompts.mjs`](shared/prompts.mjs) to customize:
- Code generation rules
- Default theme (dark mode, colors, etc.)
- Allowed/blocked patterns
- The SingularityDB client template

### Security Rules
Edit [`shared/security.mjs`](shared/security.mjs) to adjust:
- Injection detection patterns
- Blocked content categories
- Input length limits
- Output scan patterns

### Rate Limits
In [`aws/tweet-watcher/index.mjs`](aws/tweet-watcher/index.mjs):
- `max_results` — how many tweets to process per poll
- Rate limit per user (default: 2/hour)
- Poll frequency (EventBridge rule, default: 2 min)

### Reply Format
In [`poller/poll-and-reply.mjs`](poller/poll-and-reply.mjs):
- `replyText` template
- Cooldown between replies
- Polling interval

See [`docs/customization.md`](docs/customization.md) for more details.

## Troubleshooting

### "AWS CLI not configured"
Run `aws configure` and set your access key, secret, and region.

### Lambda deployment fails
- Check IAM role has propagated (script waits 10s, may need longer)
- Ensure your AWS account has Lambda service access
- Check CloudWatch logs: `aws logs tail /aws/lambda/singularity-code-runner`

### No tweets being processed
- Verify `WATCHED_TWEET_ID` is set correctly
- Check X API Bearer token is valid
- Look at CloudWatch logs for the tweet watcher
- Ensure EventBridge rule is enabled: `aws events describe-rule --name singularity-tweet-poll`

### Apps not deploying to GitHub Pages
- Verify GitHub token has `repo` scope
- Check the builds repo exists and has GitHub Pages enabled
- Ensure the `main` branch is set as the Pages source

### Reply poller not working
- Ensure OpenClaw is running with CDP on the configured port
- Check `SINGULARITY_DB_URL` is set correctly
- Run with `--once` flag to debug: `node poller/poll-and-reply.mjs --once`

## Project Structure

```
singularity-engine/
├── aws/
│   ├── code-runner/       # Claude code generation Lambda
│   ├── deployer/          # GitHub Pages deployment Lambda
│   └── tweet-watcher/     # X API polling Lambda
├── bin/
│   └── setup.mjs          # Interactive CLI setup
├── db/
│   ├── client.js          # Browser-embeddable DB client
│   ├── deploy.sh          # SingularityDB AWS deployment
│   └── lambda/            # DB API Lambda function
├── docs/
│   ├── architecture.md    # Detailed architecture documentation
│   └── customization.md   # Customization guide
├── poller/
│   └── poll-and-reply.mjs # Local reply automation
├── shared/
│   ├── prompts.mjs        # Claude system prompts
│   └── security.mjs       # Input/output security scanning
├── deploy-aws.sh          # One-command AWS deployment
├── .env.example           # Environment template
└── package.json           # Scripts and metadata
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) — do whatever you want with it.

## Built With

- **[Claude](https://anthropic.com)** — AI code generation (Anthropic)
- **[OpenClaw](https://openclaw.com)** — AI agent framework for browser automation
- **[GitHub Pages](https://pages.github.com)** — free static hosting
- **AWS Lambda + DynamoDB + API Gateway** — serverless backend

---

*Tweet a request. Get a live app. No humans in the loop.* 🦀
