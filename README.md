# 🤖 Singularity Builds

**AI-generated apps built in real-time.** Every file in this repo was created by an AI agent in under 60 seconds — no human touched the code.

🔗 **Live:** [metatransformer.github.io/singularity-builds](https://metatransformer.github.io/singularity-builds)

## What Is This?

An AI agent monitors replies to a tweet. When someone requests an app, the AI:

1. Reads the request
2. Builds a complete single-page HTML app (CSS + JS inline)
3. Commits & deploys to GitHub Pages
4. Replies with a live link

All in under 60 seconds. No human in the loop.

## How It Works

- **Agent framework:** [OpenClaw](https://openclaw.ai) — an open-source AI agent platform
- **Build pipeline:** Agent receives request → generates HTML → git push → GitHub Pages auto-deploys
- **Replies:** Agent posts the live URL back in the thread

## Set Up Your Own

Want to run this with your own OpenClaw instance? Here's how:

### Prerequisites
- [OpenClaw](https://openclaw.ai) installed and configured
- A GitHub repo with Pages enabled (deploy from `main` branch)
- X/Twitter account connected via browser automation

### Steps

1. **Fork this repo** and enable GitHub Pages (Settings → Pages → Deploy from branch `main`)

2. **Create a queue file** to track incoming requests:
   ```bash
   touch /tmp/singularity-queue.jsonl
   ```

3. **Set up a polling script** that watches for tweet replies and appends to the queue:
   ```jsonl
   {"author":"username","text":"build me a calculator","tweet_id":"123456","reply_tweet_id":"789012","status":"pending"}
   ```

4. **Create an OpenClaw cron job** that:
   - Reads pending items from the queue
   - Builds a single HTML file per request (all CSS/JS inline)
   - Commits to `builds/` or `apps/` directory
   - Pushes to GitHub
   - Replies via browser with the GitHub Pages URL
   - Marks the queue item as `done`

5. **Deploy:** GitHub Pages will serve your builds at `https://<username>.github.io/<repo>/`

### Build Guidelines
- All CSS and JS must be inline (single HTML file, no external dependencies except CDN libs)
- Dark theme (`#0a0a0a` background) recommended
- Include a footer crediting your agent

## Examples

| App | Built For | Link |
|-----|-----------|------|
| Tetris | Showcase | [Play](https://metatransformer.github.io/singularity-builds/builds/tetris.html) |
| Snake | Showcase | [Play](https://metatransformer.github.io/singularity-builds/apps/showcase-snake/index.html) |
| Calculator | Showcase | [Use](https://metatransformer.github.io/singularity-builds/apps/showcase-calculator/index.html) |
| Pomodoro Timer | Showcase | [Use](https://metatransformer.github.io/singularity-builds/apps/showcase-pomodoro/index.html) |

## Built With

- [OpenClaw](https://openclaw.ai) — AI agent framework
- [GitHub Pages](https://pages.github.com) — hosting
- Claude (Anthropic) — AI model

## License

MIT — fork it, remix it, build your own singularity.
