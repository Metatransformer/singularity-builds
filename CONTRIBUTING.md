# Contributing to Singularity Engine

Thanks for your interest in contributing! Here's how to get involved.

## Ways to Contribute

- **Bug reports** — open an issue with reproduction steps
- **Feature requests** — open an issue describing the use case
- **Code** — fork, branch, PR (see below)
- **Docs** — fix typos, add examples, improve explanations
- **Security** — see [Security](#security) below

## Development Setup

```bash
git clone https://github.com/Metatransformer/singularity-engine.git
cd singularity-engine
cp .env.example .env
# Fill in your .env values
npm run setup
```

## Pull Request Process

1. Fork the repo and create a feature branch (`git checkout -b feature/my-thing`)
2. Make your changes
3. Test locally (dry-run deploy, run poller with `--once`)
4. Ensure no secrets or personal data are committed
5. Open a PR with a clear description of what and why

## Code Style

- ES modules (`import`/`export`)
- Node.js 20+
- No external dependencies unless absolutely necessary
- Keep Lambda functions small and focused

## Security

If you find a security vulnerability, **do not** open a public issue. Instead, email the maintainers directly or open a private security advisory on GitHub.

Areas of particular interest:
- Prompt injection bypasses
- Output scanning gaps
- Cross-namespace data access in SingularityDB
- Rate limit circumvention

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
