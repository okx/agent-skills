# OKX Agent Skills

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[English](README.md) | [中文](README.zh-CN.md)

Pre-built **skill packs** that teach AI agents (Claude, Cursor, Codex, …) when to activate and how to operate OKX through the [`okx` CLI](https://www.npmjs.com/package/@okx_ai/okx-trade-cli).

Each skill is a self-contained Markdown file with YAML frontmatter — drop it into your agent's skill directory and the agent will route matching natural-language requests to it automatically.

> The runtime (CLI / MCP server) lives in a separate repo, [`okx/agent-tradekit`](https://github.com/okx/agent-tradekit). This repository ships only the skill packs.

## Skills

| Skill | Description | Auth |
|-------|-------------|:----:|
| [`okx-cex-auth`](skills/okx-cex-auth/SKILL.md) | OAuth login / logout / session-expired recovery | — |
| [`okx-cex-market`](skills/okx-cex-market/SKILL.md) | Public market data: prices, candles, orderbook, funding rate, open interest, technical indicators (70+) | No |
| [`okx-cex-trade`](skills/okx-cex-trade/SKILL.md) | Order management: spot, perpetual swap, delivery futures, options, TP/SL and trailing-stop algo orders | Yes |
| [`okx-cex-portfolio`](skills/okx-cex-portfolio/SKILL.md) | Account: balances, positions, P&L, fees, fund transfers | Yes |
| [`okx-cex-bot`](skills/okx-cex-bot/SKILL.md) | Trading bots: spot/contract grid and DCA bots | Yes |
| [`okx-cex-earn`](skills/okx-cex-earn/SKILL.md) | Earn: Simple Earn, on-chain staking, Dual Investment (双币赢), AutoEarn | Yes |
| [`okx-cex-smartmoney`](skills/okx-cex-smartmoney/SKILL.md) | Smart Money: leaderboard traders, positions, consensus signals | Yes |
| [`okx-sentiment-tracker`](skills/okx-sentiment-tracker/SKILL.md) | Crypto news aggregation and coin sentiment analysis | Yes |
| [`okx-cex-skill-mp`](skills/okx-cex-skill-mp/SKILL.md) | Skills marketplace: discover, install, update, remove third-party skills | Yes |

## Quick Start

**Prerequisites:** Node.js >= 18

```bash
# 1. Install the CLI
npm install -g @okx_ai/okx-trade-cli

# 2. Configure OKX API credentials
okx config init
```

Then drop the skill folders you need from `skills/` into your agent's skill directory (path varies by client). See [`skills/README.md`](skills/README.md) for the format spec and routing details.

## Documentation

| Document | Description |
|----------|-------------|
| [Skills](skills/README.md) | Skill format, routing, and contribution rules |
| [Contributing](CONTRIBUTING.md) | Branch and PR conventions |
| [Reviewing](REVIEWING.md) | Skill review checklist |
| [Security](SECURITY.md) | Vulnerability reporting |

## License

MIT — see [LICENSE](LICENSE).
