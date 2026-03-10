# agent-skills

A collection of AI agent skills for OKX exchange operations. Each skill is a self-contained Markdown file that tells an AI agent how to use the `okx` CLI to perform a specific category of tasks — market data queries, portfolio management, trading, and bot automation.

## Skills

| Skill | Description | Auth Required |
|-------|-------------|---------------|
| [`okx-cex-market`](skills/okx-cex-market/SKILL.md) | Public market data: prices, order books, candles, funding rates, open interest, instruments | No |
| [`okx-cex-trade`](skills/okx-cex-trade/SKILL.md) | Order management: spot, perpetual swap, delivery futures, options, TP/SL and trailing stop algo orders | Yes |
| [`okx-cex-portfolio`](skills/okx-cex-portfolio/SKILL.md) | Account operations: balances, positions, P&L, fees, fund transfers | Yes |
| [`okx-cex-bot`](skills/okx-cex-bot/SKILL.md) | Automated strategies: spot/contract grid bots and DCA bots | Yes |

## Requirements

- [`okx` CLI](https://www.npmjs.com/package/@okx_ai/okx-trade-cli) installed:
  ```bash
  npm install -g @okx_ai/okx-trade-cli
  ```
- For authenticated skills: OKX API credentials configured in `~/.okx/config.toml`

## Skill Format

Each skill is a Markdown file with a YAML frontmatter header:

```yaml
---
name: skill-name
description: "Trigger description for the AI agent routing system."
license: Apache-2.0
metadata:
  author: okx
  version: "1.0.0"
  agent:
    requires:
      bins: ["okx"]
---
```

The `description` field is used by the agent to decide when to activate the skill. It should enumerate the natural-language phrases and scenarios that the skill handles.

## Usage

Skills are loaded by AI agents to provide contextual instructions for CLI-based tasks. The agent reads the skill document and follows the command examples and operation flows described within.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add or improve skills.

## License

MIT — see [LICENSE](LICENSE).
