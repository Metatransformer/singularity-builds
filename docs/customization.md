# Customization Guide

## Changing the AI Model

In `aws/code-runner/run.mjs`, change the model:

```javascript
const message = await client.messages.create({
  model: "claude-sonnet-4-20250514",  // Change to any Anthropic model
  max_tokens: 16000,
  // ...
});
```

## Changing the Default Theme

In `shared/prompts.mjs`, modify the system prompt:

```
Make the app beautiful with a dark theme by default.
```

Change to any theme you want — light mode, specific color schemes, etc.

## Adjusting Rate Limits

In `aws/tweet-watcher/index.mjs`:

```javascript
// Change from 2 to whatever you want
if (userBuilds >= 2) { ... }
```

## Adding New Content Filters

In `aws/tweet-watcher/index.mjs`, add patterns to `BLOCKED_REQUESTS`:

```javascript
const BLOCKED_REQUESTS = [
  // ... existing patterns
  /your-new-pattern/i,
];
```

## Changing the Reply Format

In `poller/poll-and-reply.mjs`:

```javascript
const replyText = `your custom reply template with ${appUrl}`;
```

## Using a Different Trigger (Not Twitter)

The Code Runner and Deployer are generic — they accept a build request and produce a deployed app. You can replace the Tweet Watcher with:

- A Discord bot
- A Slack integration
- A web form
- A CLI tool
- Any HTTP endpoint

Just invoke the Code Runner Lambda with:
```json
{
  "request": "build me a calculator",
  "appId": "unique-app-id",
  "tweetId": "optional-reference-id",
  "userId": "requesting-user"
}
```

## Changing the Deploy Target

The Deployer uses the GitHub Contents API. To deploy elsewhere:

1. Replace `pushToGitHub()` in `aws/deployer/index.mjs`
2. Return a URL where the app is accessible
3. Everything else works the same

Options: Netlify, Vercel, Cloudflare Pages, S3 + CloudFront, etc.

## Poll Frequency

The EventBridge rule polls every 2 minutes. Change in `deploy-aws.sh`:

```bash
--schedule-expression "rate(5 minutes)"  # Less frequent
--schedule-expression "rate(1 minute)"   # More frequent (costs more)
```

## Max App Size

In `aws/code-runner/run.mjs`, adjust `max_tokens`:

```javascript
max_tokens: 16000,  // ~16KB of HTML, increase for larger apps
```

Note: Larger apps cost more per build (more output tokens).
