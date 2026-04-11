# codex-autopilot

Autopilot for Codex

[![License](https://img.shields.io/github/license/amphoreus-ai/codex-autopilot)](LICENSE)
[![Stars](https://img.shields.io/github/stars/amphoreus-ai/codex-autopilot?style=social)](https://github.com/amphoreus-ai/codex-autopilot/stargazers)

## Background

When coding agents are rewarded for saying "done", they can stop early or claim completion without real work.

codex-autopilot installs a Codex Stop hook that audits the last assistant response against the user transcript. A second Codex agent judges whether the assistant has done meaningful work or is trying to finish prematurely.

Only complete and failed are allowed to finish immediately. Incomplete and waiting are blocked with a reason so the agent must continue.

## Install

Prerequisites:

- [Codex CLI](https://github.com/openai/codex) installed and available on PATH
- [jq](https://jqlang.github.io/jq/) installed and available on PATH

In the project where you want autopilot enabled:

```bash
npx github:amphoreus-ai/codex-autopilot
```

What this installer does:

- Creates or updates .codex/config.toml
- Forces [features] codex_hooks = true
- Creates or updates .codex/hooks.json
- Installs .codex/hooks/codex-autopilot/autopilot.sh and judge-schema.json
- Merges hook entries idempotently (safe to re-run)

After installation, run Codex once interactively in that repository and approve trust, otherwise hooks will not load.

## Usage

Run Codex as usual in a trusted repository:

```bash
codex
```

Quick verification after install:

```bash
cat .codex/config.toml
cat .codex/hooks.json
```

Expected key values:

- `[features]` section contains codex_hooks = true
- Stop hook command points to `sh .codex/hooks/codex-autopilot/autopilot.sh`

## Contributing

Contributions are welcome.

Please open an issue first for major changes so implementation direction can be aligned early.

## License

[MIT](LICENSE) © Zijian Zhang
