# OKX Agent Skills

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

[English](README.md) | [中文](README.zh-CN.md)

为 AI agent（Claude、Cursor、Codex …）预置的 **skill 包**：告诉 agent 何时激活、以及如何通过 [`okx` CLI](https://www.npmjs.com/package/@okx_ai/okx-trade-cli) 操作 OKX。

每个 skill 是一份带 YAML frontmatter 的 Markdown 文件——把它放进 agent 的 skill 目录后，agent 会自动把匹配的自然语言请求路由到对应 skill。

> 运行时（CLI / MCP Server）在独立仓库 [`okx/agent-tradekit`](https://github.com/okx/agent-tradekit) 中维护。本仓只承载 skill 包。

## Skills 列表

| Skill | 说明 | 鉴权 |
|-------|------|:----:|
| [`okx-cex-auth`](skills/okx-cex-auth/SKILL.md) | OAuth 登录 / 登出 / 会话过期恢复 | — |
| [`okx-cex-market`](skills/okx-cex-market/SKILL.md) | 公开行情：价格、K线、盘口、资金费率、持仓量、技术指标（70+） | 否 |
| [`okx-cex-trade`](skills/okx-cex-trade/SKILL.md) | 订单管理：现货、永续合约、交割合约、期权、止盈止损 / 追踪止损算法单 | 是 |
| [`okx-cex-portfolio`](skills/okx-cex-portfolio/SKILL.md) | 账户：余额、持仓、盈亏、手续费、资金划转 | 是 |
| [`okx-cex-bot`](skills/okx-cex-bot/SKILL.md) | 交易机器人：现货/合约网格、DCA（现货 & 合约） | 是 |
| [`okx-cex-earn`](skills/okx-cex-earn/SKILL.md) | 赚币：简单赚币、链上质押、双币赢、自动赚币 | 是 |
| [`okx-cex-smartmoney`](skills/okx-cex-smartmoney/SKILL.md) | 聪明钱：牛人榜、交易员持仓、共识信号 | 是 |
| [`okx-sentiment-tracker`](skills/okx-sentiment-tracker/SKILL.md) | 加密新闻聚合与币种情绪分析 | 是 |
| [`okx-cex-skill-mp`](skills/okx-cex-skill-mp/SKILL.md) | Skill 市场：发现、安装、更新、卸载第三方 skill | 是 |

## 快速开始

**前置要求：** Node.js >= 18

```bash
# 1. 安装 CLI
npm install -g @okx_ai/okx-trade-cli

# 2. 配置 OKX API 凭证
okx config init --lang zh
```

随后把 `skills/` 里需要的 skill 目录放进 agent 的 skill 目录（不同客户端路径不同）。格式说明与路由细节见 [`skills/README.zh-CN.md`](skills/README.zh-CN.md)。

## 文档导航

| 文档 | 说明 |
|------|------|
| [Skills](skills/README.zh-CN.md) | Skill 格式、路由与贡献规范 |
| [贡献指南](CONTRIBUTING.md) | 分支与 PR 规范 |
| [Review 规范](REVIEWING.md) | Skill review checklist |
| [安全政策](SECURITY.md) | 漏洞上报 |

## 许可证

MIT — 见 [LICENSE](LICENSE)。
