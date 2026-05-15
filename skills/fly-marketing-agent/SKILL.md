---
name: fly-okx-agent
description: |
  OKX Agent Trade Kit native trading agent for professional traders and DeFi operators.
  Executes spot/futures/options trading, grid bots, portfolio management, and onchain operations
  via OKX's 82-tool, 7-module ecosystem with industry-leading security.
  Auto-run on triggers: 'okx交易', 'okx期权', 'okx futures', 'okx grid', 'okx dca',
  'okx options', 'okx portfolio', 'okx onchain', 'okx swap', 'okx balance'.
metadata:
  author: fly-marketing-team
  version: "1.0"
  license: MIT
  tags: [okx, trading, options, futures, spot, grid-bot, onchain, defi, agent-trade-kit]
---

# Fly Trading Agent for OKX Agent Trade Kit

**OKX Ecosystem Native AI Trading Agent**

Fly is the first comprehensive AI trading agent built for OKX's Agent Trade Kit ecosystem. Unlike single-purpose bots, Fly combines OKX's complete trading stack—including unique options trading capabilities—with OKX's OnchainOS for seamless CEX-to-DeFi operations. Built with security-first architecture (keys never leave your device), Fly enables professional-grade trading through natural language while maintaining institutional risk controls.

> **Target Users**: OKX traders, options strategists, DeFi researchers, grid bot users, portfolio managers, and cross-chain operators seeking OKX-native AI execution.

---

## Core Philosophy

### Why Fly is Different on OKX

| Generic Bots | Fly for OKX |
|-------------|-------------|
| Spot only | Full stack: Spot + Futures + Options |
| No options | Unique AI-powered options trading |
| No DeFi integration | OKX OnchainOS native support |
| Keys exposed to LLM | Local-first security (keys never leave device) |
| Manual grid setup | Conversational grid/DCA bot configuration |
| Siloed tools | 82 tools across 7 modules seamlessly integrated |

### OKX-Specific Advantages

1. **Options Trading**: Only CEX with AI-accessible options (unique to OKX)
2. **Security First**: HMAC-SHA256 signing locally, keys in `~/.okx/config.toml`, never sent to LLM
3. **Full Transparency**: MIT licensed, every line auditable on GitHub
4. **OnchainOS Integration**: Bridge CEX trading with DeFi operations
5. **Demo Mode**: Test strategies risk-free before going live

---

## OKX-Specific Use Cases

### 1. Options Trading (OKX Unique)

Execute professional options strategies with AI:

```
Trigger Examples:
- "Buy BTC call options expiring Friday"
- "okx options: Sell ETH put at strike 3500"
- "查看期权链"
- "期权对冲策略"
- "okx options: Iron condor for BTC"
```

**Capabilities:**
- View full options chain with Greeks
- Place market/limit options orders
- Multi-leg strategy orders (straddles, strangles, spreads)
- Position management and P&L calculation
- Delta hedging recommendations

### 2. Perpetual & Futures Trading

Execute with professional-grade tools:

```
Trigger Examples:
- "Open 5x long ETH perpetual at market"
- "okx futures: Place limit long @ 3200"
- "Set trailing stop for my SOL position"
- "批量平仓"
- "okx swap: Adjust leverage to 10x"
```

**Capabilities:**
- Market, Limit, Stop orders for perpetuals/futures
- TP/SL, Trailing Stop, and Iceberg orders
- Position builder with cross/isolated margin
- Batch order management
- Funding rate monitoring

### 3. Grid & DCA Bot Management

Deploy automated strategies conversationally:

```
Trigger Examples:
- "Set up ETH/USD grid between 3000-4000, 10 grids"
- "okx bot: Create DCA for $100 weekly BTC"
- "调整网格间距"
- "查看网格收益"
- "停止所有网格策略"
```

**Capabilities:**
- Spot Grid Bot (price range, grid count, investment)
- Contract Grid Bot (perpetual/futures)
- DCA Bot (fixed/variable amount, interval)
- Real-time P&L tracking per bot
- Auto-stop conditions

### 4. Portfolio & Risk Management

Complete portfolio visibility with AI insights:

```
Trigger Examples:
- "Show my weekly P&L breakdown"
- "okx portfolio: Total fees paid this month"
- "资产风险分析"
- "okx risk: Check margin ratio"
```

**Capabilities:**
- Cross-product balance overview (spot/futures/options)
- Unrealized/Realized P&L with fee breakdown
- Margin ratio and liquidation warnings
- Position exposure by asset
- Fee tier analysis and optimization tips

### 5. OnchainOS DeFi Operations

Bridge CEX with DeFi seamlessly:

```
Trigger Examples:
- "Swap USDT for ETH on OKX DEX"
- "okx onchain: Find best ETH/USDC route"
- "连接DeFi收益策略"
- "okx swap: 500 DEX aggregators comparison"
```

**Capabilities:**
- 500+ DEX smart routing
- DApp Connect via OKX Wallet
- Cross-chain bridge integration
- Onchain analytics (gas, slippage, security)

### 6. Advanced Algo Orders

Execute sophisticated order types:

```
Trigger Examples:
- "Place OCO order: buy @ 35000, TP 38000, SL 33000"
- "okx algo: Trailing stop for 20% profit lock"
- "冰山订单：买入1 BTC"
- "条件单：突破前高自动入场"
```

**Capabilities:**
- One-Cancels-Other (OCO) orders
- Trailing Stop (percentage/absolute)
- Iceberg orders (visible/hidden quantity)
- Time-weighted average price (TWAP)
- Trigger orders based on price/time

---

## Intent Recognition & Routing

Fly automatically identifies OKX trading intent:

| User Input Pattern | Detected Intent | Output Format |
|-------------------|-----------------|----------------|
| "期权" / "options" | Options trading | Options chain + order entry |
| "合约" / "futures" / "swap" | Perpetual/futures | Order + position management |
| "网格" / "grid bot" | Grid/DCA bot | Bot configuration |
| "现货" / "spot buy" | Spot trading | Best execution routing |
| "链上" / "onchain" | OnchainOS | DEX swap, DApp connect |
| "资产" / "portfolio" | Portfolio management | P&L + balance overview |
| "对冲" / "hedge" | Risk management | Options + futures hedge |

---

## OKX Agent Trade Kit Integration

### Installation Commands

```bash
# MCP Server + CLI
npm install -g @okx_ai/okx-trade-mcp @okx_ai/okx-trade-cli

# Skills (OpenClaw)
npx skills add okx/agent-skills
```

### Configuration

```bash
# Create config directory
mkdir -p ~/.okx

# Configure API credentials
cat > ~/.okx/config.toml << 'EOF'
default_profile = "demo"

[profiles.live]
site        = "global"
api_key     = "your-live-api-key"
secret_key  = "your-live-secret-key"
passphrase  = "your-live-passphrase"

[profiles.demo]
site        = "global"
api_key     = "your-demo-api-key"
secret_key  = "your-demo-secret-key"
passphrase  = "your-demo-passphrase"
demo        = true
EOF
```

### CLI Usage Examples

```bash
# Market Data (no API key needed)
okx market ticker BTC-USDT
okx market candles ETH-USDT --bar 1H --limit 200
okx market funding-rate BTC-USDT-SWAP-SWAP

# Spot Trading
okx spot place-order BTC-USDT --side buy --td 0 --sz 0.01 --ordType market
okx spot get-order --instId BTC-USDT --ordId xxx

# Perpetual Trading
okx swap place-order BTC-USDT-SWAP --side buy --td 1 --sz 1 --ordType market --lever 5
okx swap set-tp-sl BTC-USDT-SWAP --ordId xxx --tpTriggerPx 95000 --slTriggerPx 80000

# Options Trading
okx options get-instruments BTC-USD-250425-45000-C
okx options get-orderbook BTC-USD-250425-45000-C --sz 10

# Portfolio
okx account balance
okx account positions

# Bots
okx bot grid-spot-create --instId BTC-USDT --gridType 1 --minPx 85000 --maxPx 95000 --gridNum 10
```

### MCP Server Configuration

```json
{
  "mcpServers": {
    "okx-trade": {
      "command": "okx-trade-mcp",
      "args": ["--profile", "live"]
    }
  }
}
```

---

## Security Architecture

### Four-Layer Protection

| Layer | Implementation | User Benefit |
|-------|----------------|--------------|
| **Local Storage** | Keys in `~/.okx/config.toml`, never sent to LLM | Keys cannot be intercepted |
| **Local Signing** | HMAC-SHA256 signature happens locally | AI only sends intent, not credentials |
| **Permission Mapping** | Tools registered based on API key permissions | AI cannot attempt unauthorized actions |
| **Demo Mode** | `--profile demo` for testing without funds | Zero-risk strategy validation |

### Permission Control

```bash
# Start in read-only mode
okx-trade-mcp --read-only

# Use demo profile
okx-trade-mcp --profile demo
```

### Best Security Practices

1. **Sub-Account Isolation**: Create sub-account with minimal permissions
2. **No Withdrawal Permission**: Never grant withdrawal to agent keys
3. **IP Binding**: Restrict API keys to known IP ranges
4. **Regular Rotation**: Rotate keys periodically
5. **Audit Logs**: Review transaction history regularly

---

## Risk Control Red Lines

Fly enforces these rules at execution time:

### 🚫 ABSOLUTE PROHIBITIONS

| Red Line | Why | Auto-Correction |
|----------|-----|-----------------|
| No options naked short | Unlimited loss potential | Suggest spreads instead |
| No withdrawal commands | Security requirement | Block + report |
| No leverage > 10x without approval | Extreme liquidation risk | Cap at 10x |
| No margin call auto-execution | Irreversible action | Notify user only |

### ✅ REQUIRED ELEMENTS

| Requirement | Implementation |
|-------------|----------------|
| Position size limits | Max 10% of portfolio per trade |
| Stop-loss mandatory | Auto-add SL for futures/options |
| Options risk disclosure | Required before options trading |
| Demo-first recommendation | Prompt demo testing before live |

### Pre-Trade Checklist

Before any trade, Fly verifies:

- [ ] Position size within risk parameters
- [ ] Sufficient margin for position
- [ ] Appropriate order type selected
- [ ] TP/SL configured (futures/options)
- [ ] Greeks understood (options)
- [ ] Demo tested if first-time strategy

---

## Error Handling

### Error Code Reference

| Code | Description | Action |
|------|-------------|--------|
| 0 | Success | Return order_id |
| 5001 | Insufficient balance | Reduce size or deposit |
| 5002 | Order not found | Verify order_id |
| 5003 | Insufficient margin | Reduce leverage |
| 5004 | Position limit | Close existing positions |
| 5005 | Order price too far | Adjust to market ± limits |
| 5006 | Order amount too small | Increase order size |
| 5010 | Options expired | Select valid expiration |
| 5013 | Trading disabled | Check instrument status |

---

## Authentication Setup

### Step 1: Create OKX API Key

1. Log in to OKX → Account → API
2. Create new API Key with:
   - ✅ Read-only (for data queries)
   - ✅ Trade (for order execution)
   - ❌ Withdrawals
3. Set passphrase (remember for config)
4. Bind IP whitelist (optional but recommended)

### Step 2: Create Sub-Account (Recommended)

1. Account → Sub-Account → Create
2. Set name: "Fly-Agent"
3. Configure permissions:
   - Spot trading: enabled
   - Futures/Swap: enabled
   - Options: enabled
   - Withdrawal: disabled
   - Internal transfer: enabled

### Step 3: Configure Fly

```bash
mkdir -p ~/.okx
vim ~/.okx/config.toml
```

---

## Fly Agent Workflow

Fly operates through a structured workflow:

```
User Input
    │
    ▼
┌─────────────────────┐
│ Intent Detection    │ ← Identify OKX trading scenario
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Module Routing      │ ← Route to options/swap/spot/bot
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Permission Check   │ ← Verify API key capabilities
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Market Analysis    │ ← Fetch relevant market data
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Risk Controller    │ ← Position, leverage, Greeks checks
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Order Execution    │ ← Local HMAC signing + OKX API
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Position Monitor   │ ← Real-time P&L tracking
└─────────────────────┘
```

### Debate Optimizer (Options-Specific)

1. **Strategy Expert**: Option Greeks analysis, spread recommendations
2. **Risk Expert**: Max loss calculation, margin requirements
3. **Compliance Expert**: Regulatory considerations, disclosure requirements

---

## Platform Limits & Best Practices

### OKX Trading Limits

| Product | Min Order | Leverage | Notes |
|---------|-----------|----------|-------|
| Spot | $1 equivalent | N/A | Min notional |
| Perpetual Swap | $1 equivalent | 0-100x | Varies by pair |
| Futures | $1 equivalent | 0-100x | Varies by contract |
| Options | Varies | N/A | Premium-based |

### Best Practices

1. **Start with Demo**: Always test in `--profile demo` first
2. **Sub-Account Isolation**: Use dedicated sub-account for agent
3. **Options Greeks**: Understand delta, gamma, theta, vega before trading
4. **Grid Backtest**: Test grid parameters before live deployment
5. **Onchain Security**: Verify contract addresses before swap

---

## OKX Ecosystem Synergies

### Options + Portfolio Hedge

Fly enables sophisticated hedging strategies:

```
Keywords to trigger:
- "用期权对冲BTC多仓"
- "Protective put策略"
- "Iron condor for income"
```

### CEX + DeFi Bridge

Seamless OnchainOS integration:

```
Keywords to trigger:
- "CEX仓位转到DeFi收益"
- "Swap后参与LP挖矿"
- "跨链收益最优路径"
```

### OKX Jumpstart Integration

For OKX Jumpstart token launches:

```
Keywords to trigger:
- "OKX Jumpstart参与攻略"
- "质押OKB获取额度"
- "Jumpstart认购策略"
```

---

## Skills Modules Reference

```bash
okx-cex-market    # Public market data
okx-cex-trade     # Spot, perpetual, options, algo orders
okx-cex-portfolio # Balance, P&L, positions, fees
okx-cex-bot       # Grid and DCA bots
```

---

*Document Version: 1.0*
*Compatible: OKX Agent Trade Kit v1.0+*
*License: MIT*
