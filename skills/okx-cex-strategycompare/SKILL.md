---
name: okx-cex-strategycompare
description: "This skill should be used when the user asks to 'compare my strategies', 'compare my bots', 'which bot is performing best', 'rank my grid bots', 'strategy performance comparison', 'show me all bot P&L', 'compare grid vs DCA', 'which strategy should I keep', 'strategy leaderboard', 'compare bot returns', 'annualized return comparison', 'which bot is losing money', or any request to compare, rank, or evaluate the performance of multiple grid or DCA bots across instruments or types on OKX CEX. Aggregates data from okx-cex-bot, okx-cex-market, and okx-cex-portfolio. Requires API credentials."
license: MIT
metadata:
  author: okx
  version: "1.0.0"
  homepage: "https://www.okx.com"
  agent:
    emoji: "📊"
    requires:
      bins: ["okx"]
    install:
      - id: npm
        kind: node
        package: "@okx_ai/okx-trade-cli"
        bins: ["okx"]
        label: "Install okx CLI (npm)"
---

# OKX CEX Strategy Compare

Cross-strategy performance comparison for grid and DCA bots on OKX. Aggregates P&L, annualized return, and risk metrics across all active bots to help you identify top performers, underperformers, and actionable rebalancing decisions. **Requires API credentials.**

## Prerequisites

1. Install `okx` CLI:
   ```bash
   npm install -g @okx_ai/okx-trade-cli
   ```
2. At least one active grid or DCA bot (see `okx-cex-bot` to create bots).
3. Configure credentials:
   ```bash
   okx config show
   ```

## Credential & Profile Check

**Run this check before any authenticated command.**

### Step A — Verify credentials

```bash
okx config show       # verify configuration status (output is masked)
```

- If the command returns an error or shows no configuration: **stop all operations**, guide the user to run `okx config init`, and wait for setup to complete before retrying.
- If credentials are configured: proceed to Step B.

### Step B — Confirm profile (required)

`--profile` is **required** for all authenticated commands. Never add a profile implicitly.

| Value | Mode | Funds |
|---|---|---|
| `live` | 实盘 | Real funds |
| `demo` | 模拟盘 | Simulated funds |

**Resolution rules:**
1. Current message intent is clear (e.g. "real" / "实盘" / "live" → `live`; "test" / "模拟" / "demo" → `demo`) → use it and inform the user: `"Using --profile live (实盘)"` or `"Using --profile demo (模拟盘)"`
2. Current message has no explicit declaration → check conversation context for a previous profile:
   - Found → use it, inform user: `"Continuing with --profile live (实盘) from earlier"`
   - Not found → ask: `"Live (实盘) or Demo (模拟盘)?"` — wait for answer before proceeding

## Demo vs Live Mode

Profile is the single control for 实盘/模拟盘 switching — exactly two options:

| `--profile` | Mode | Funds |
|---|---|---|
| `live` | 实盘 | Real funds |
| `demo` | 模拟盘 | Simulated funds |

**Rules:**
- All commands in this skill are read-only — confirm profile once, then run all data collection commands
- Every response must append: `[profile: live]` or `[profile: demo]`
- Do **not** use the `--demo` flag — use `--profile` instead

## Skill Routing

- For market data (prices, candles, funding rates) → use `okx-cex-market`
- For account balance, positions, P&L → use `okx-cex-portfolio`
- For creating/stopping/managing individual bots → use `okx-cex-bot`
- For **comparing and ranking multiple strategies** → use `okx-cex-strategycompare` (this skill)

## Quickstart

```bash
# Step 1: Collect all active bot lists
okx bot grid orders --algoOrdType grid
okx bot grid orders --algoOrdType contract_grid
okx bot dca orders

# Step 2: Get details for each bot (run for every algoId found above)
okx bot grid details --algoOrdType grid --algoId <algoId>
okx bot grid details --algoOrdType contract_grid --algoId <algoId>
okx bot dca details --algoId <algoId>

# Step 3: Enrich with current market prices (for context)
okx market ticker <instId>
```

## Comparison Workflows

### Full Strategy Leaderboard
> User: "Compare all my active bots and rank by performance"

```
1. okx-cex-bot       okx bot grid orders --algoOrdType grid              → spot grid list
2. okx-cex-bot       okx bot grid orders --algoOrdType contract_grid      → contract grid list
3. okx-cex-bot       okx bot dca orders                                   → DCA list
4. okx-cex-bot       (for each grid algoId) okx bot grid details --algoOrdType <type> --algoId <id>
5. okx-cex-bot       (for each DCA algoId)  okx bot dca details --algoId <id>
        ↓ build comparison table (see Output Format)
6. present ranked leaderboard + recommendations
```

### Grid vs DCA on Same Instrument
> User: "Compare my BTC grid bot vs my BTC DCA bot"

```
1. okx-cex-bot       okx bot grid orders --algoOrdType grid               → find BTC grid algoId
2. okx-cex-bot       okx bot dca orders                                   → find BTC DCA algoId
3. okx-cex-bot       okx bot grid details --algoOrdType grid --algoId <id>
4. okx-cex-bot       okx bot dca details --algoId <id>
5. okx-cex-market    okx market ticker BTC-USDT                           → current price context
        ↓ compare side-by-side (see Side-by-Side Format)
```

### Compare Grid Bots Across Instruments
> User: "Which of my grid bots is performing best?"

```
1. okx-cex-bot       okx bot grid orders --algoOrdType grid               → list all spot grids
2. okx-cex-bot       (for each algoId) okx bot grid details --algoOrdType grid --algoId <id>
        ↓ rank by pnlRatio (descending)
```

### Identify Underperformers
> User: "Which bots are losing money? Should I stop them?"

```
1. (collect all bot details — same as Full Strategy Leaderboard steps 1–5)
        ↓ filter bots where pnl < 0 or pnlRatio < 0
2. okx-cex-market    okx market candles <instId> --bar 1D --limit 14      → 2-week price trend
3. present underperformers with context + stop recommendation
```

### Compare Annualized Returns
> User: "Which strategy has the best annualized return?"

```
1. (collect all bot details — same as Full Strategy Leaderboard)
        ↓ sort by totalAnnRate (grid) or calculate annualized rate for DCA from upl/initOrdAmt
```

## Operation Flow

### Step 0 — Credential & Profile Check

Before any authenticated command, determine profile (see "Credential & Profile Check" above).

### Step 1 — Collect All Active Bot Data

Run all three list commands in parallel:

```bash
okx --profile <profile> bot grid orders --algoOrdType grid
okx --profile <profile> bot grid orders --algoOrdType contract_grid
okx --profile <profile> bot dca orders
```

- If a list command returns empty: skip that bot type, note it in output
- Record all `algoId` values from each list

### Step 2 — Fetch Details for Every Bot

For each `algoId` from Step 1, fetch details:

```bash
okx --profile <profile> bot grid details --algoOrdType grid --algoId <id>
okx --profile <profile> bot grid details --algoOrdType contract_grid --algoId <id>
okx --profile <profile> bot dca details --algoId <id>
```

Extract these fields per bot:

| Field | Grid Source | DCA Source |
|---|---|---|
| Bot ID | `algoId` | `algoId` |
| Type | `algoOrdType` (`grid` / `contract_grid`) | `dca` |
| Instrument | `instId` | `instId` |
| Direction | `direction` (contract grid) or `—` | `direction` |
| Investment | `investAmt` (USDT) | `initOrdAmt + safetyOrdAmt × fillSafetyOrds` |
| PnL (USDT) | `pnl` | `upl` |
| PnL Ratio (%) | `pnlRatio × 100` | `upl / totalInvested × 100` |
| Ann. Return (%) | `totalAnnRate × 100` | *(calculate: see below)* |
| Runtime | derive from `cTime` to now | derive from `cTime` to now |
| Status | `state` | `state` |
| Grid Range | `minPx – maxPx` | TP: `tpPx` / SL: `slPx` |

**DCA Annualized Return Calculation:**
If `upl` and total runtime `T` (in days) are available:
```
ann_return = (upl / totalInvested) / T × 365 × 100
```
Where `totalInvested = initOrdAmt + safetyOrdAmt × fillSafetyOrds`.

### Step 3 — Build Comparison Table

Sort all bots by `pnlRatio` descending (best performers first). Present as a ranked table.

### Step 4 — Provide Recommendations

After the table, add a concise recommendations section:

- **Top performer**: name the #1 bot and why (highest return, efficient grid range, etc.)
- **Underperformers** (pnlRatio < 0): note them explicitly; check if price is outside grid range
- **Out-of-range grids**: if current price < `minPx` or > `maxPx`, the grid is inactive — suggest stop or range adjustment
- **DCA bots near stop-loss**: if `avgPx` is close to `slPx` (within 5%), flag as high risk
- **Action suggestions**: "Consider stopping X (losing Y USDT, price out of range)" or "Top performer: keep running bot Z (annualized +N%)"

## Output Formats

### Full Leaderboard Table

```
Strategy Performance Leaderboard [profile: live]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Rank  Type           Instrument      Dir      Invested     PnL (USDT)  PnL%    Ann%    Runtime   Status
────  ─────────────  ──────────────  ───────  ───────────  ──────────  ──────  ──────  ────────  ──────
#1    Spot Grid      BTC-USDT        —        1,000 USDT   +45.23      +4.52%  +32.1%  51 days   active
#2    Contract Grid  ETH-USDT-SWAP   long     500 USDT     +18.90      +3.78%  +27.5%  50 days   active
#3    DCA            BTC-USDT-SWAP   long     300 USDT     +6.10       +2.03%  +18.4%  40 days   active
#4    Spot Grid      SOL-USDT        —        200 USDT     -3.45       -1.73%  -12.6%  50 days   active  ⚠️

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Invested: 2,000 USDT  |  Total PnL: +66.78 USDT (+3.34%)
```

### Side-by-Side Comparison (Two Bots)

```
Strategy Comparison: BTC Grid Bot vs BTC DCA Bot [profile: live]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                        Grid Bot            DCA Bot
                        ──────────────────  ──────────────────
Bot ID                  12345678            87654321
Type                    Spot Grid           Contract DCA
Instrument              BTC-USDT            BTC-USDT-SWAP
Direction               —                   Long (3x)
Investment              1,000 USDT          300 USDT
PnL                     +45.23 USDT         +6.10 USDT
PnL Ratio               +4.52%              +2.03%
Annualized Return       +32.1%              +18.4%
Runtime                 51 days             40 days
Grid / TP Range         $82,000 – $100,000  TP: $95,500
Current Price           $91,200             Mark: $91,200
Status                  Active ✅            Active ✅
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Winner: Grid Bot (+32.1% annualized vs +18.4%)
```

### Underperformer Alert

```
⚠️  Underperformer Alert
────────────────────────
Bot: SOL-USDT Spot Grid (algoId: 99887766)
PnL: -3.45 USDT (-1.73%)
Current Price: $118.50
Grid Range: $125.00 – $145.00

Price is BELOW the grid's lower bound ($125.00). The grid is currently
inactive — no trades are executing. Options:
  1. Stop the bot and recover assets (okx-cex-bot)
  2. Recreate with a lower range that includes current price (okx-cex-bot)
  3. Wait for price recovery into range
```

## Metrics Reference

| Metric | Definition | Where to Find |
|---|---|---|
| PnL (USDT) | Absolute profit/loss since bot started | Grid: `pnl`; DCA: `upl` |
| PnL Ratio (%) | PnL as % of invested capital | Grid: `pnlRatio × 100`; DCA: computed |
| Annualized Return (%) | PnL ratio scaled to 1 year | Grid: `totalAnnRate × 100`; DCA: computed |
| Investment | Capital committed to the bot | Grid: `investAmt`; DCA: sum of fill amounts |
| Runtime | Days since bot was created | Derived from `cTime` to current timestamp |
| Grid Range | Price range the bot operates in | `minPx` – `maxPx` |
| Fill Safety Orders | Number of DCA safety orders triggered so far | DCA: `fillSafetyOrds` |
| In-Range Status | Whether current price is within grid bounds | Compare `last` vs `minPx`/`maxPx` |

## Performance Scoring Heuristic

When ranking bots, use this priority order:

1. **Annualized Return** (primary) — highest first
2. **PnL Ratio** (secondary) — highest first
3. **In-Range Status** — active (price in range) ranks higher than out-of-range bots
4. **Capital Efficiency** — higher return per USDT invested is better

Flag bots with:
- `pnlRatio < 0` → ⚠️ Losing
- Price outside grid range → 🚫 Inactive
- DCA `avgPx` within 5% of `slPx` (long) or `slPx` within 5% of `avgPx` (short) → 🔴 Near Stop-Loss

## Cross-Skill Workflows

### Full Analysis + Action
> User: "Compare all bots, stop the worst performer"

```
1. okx-cex-strategycompare  (collect + rank all bots)         → leaderboard
2. identify worst performer (lowest pnlRatio or out-of-range)
3. okx-cex-market            okx market ticker <instId>        → confirm current price
        ↓ user approves stop
4. okx-cex-bot               okx bot grid stop --algoId <id> --algoOrdType <type> \
                               --instId <id> --stopType 2
```

### Strategy Rebalancing
> User: "I want to move funds from my worst grid to my best grid"

```
1. okx-cex-strategycompare  (collect + rank all bots)
2. identify worst and best performers
        ↓ user approves
3. okx-cex-bot               okx bot grid stop --algoId <worst_id> ...     → stop worst bot
4. okx-cex-portfolio         okx account balance USDT                       → confirm freed funds
5. okx-cex-bot               okx bot grid create ... (reinvest in best)    → expand best bot
```

### Monitor Strategy Drift
> User: "Have my strategies drifted from their original ranges?"

```
1. okx-cex-strategycompare  (collect all bot details)
2. okx-cex-market            okx market ticker <instId>  (per instrument)   → current prices
        ↓ compare current price vs minPx/maxPx for each grid bot
        ↓ compare current mark price vs avgPx/tpPx/slPx for each DCA bot
```

## Edge Cases

- **No active bots**: if all three list commands return empty, inform the user there are no active bots to compare; suggest creating bots with `okx-cex-bot`
- **Single bot only**: skip the leaderboard format; show bot details directly and note "Only one active bot found — nothing to compare against"
- **DCA pnl field**: DCA `upl` is unrealized — it fluctuates with mark price; note this in the output ("unrealized P&L, mark-price dependent")
- **Grid pnl includes realized fills**: grid `pnl` includes gains from completed buy-sell pairs plus current holdings value — more stable than DCA `upl`
- **totalAnnRate unavailable**: if `totalAnnRate` is `0` or missing (bot ran < 1 day), skip annualized return for that bot and note "insufficient runtime"
- **Contract grid direction**: `long` and `short` grids have directional risk; `neutral` is delta-neutral — note this when comparing risk profiles
- **Multiple instruments**: when comparing bots on different instruments (BTC vs ETH), note that PnL% is a fairer comparison than absolute PnL USDT

## Communication Guidelines

- **Use "bot" not "strategy"** in user-facing output (e.g., "Grid bot" not "grid strategy")
- **Always refer to DCA bots as "DCA"** — not "定投" or "recurring buy"
- **Grid bot** can be referred to as "网格" in Chinese contexts
- **Present the leaderboard table first**, then recommendations — don't bury the data in text
- **Be explicit about unrealized vs realized**: flag DCA PnL as unrealized; grid PnL as realized+unrealized
- After every response, append: `[profile: live]` or `[profile: demo]`

### Parameter Display Names

When explaining metrics to users, use display names:

| Internal Field | Display Name (EN) | Display Name (ZH) |
|---|---|---|
| `pnlRatio` | PnL ratio (%) | 收益率 (%) |
| `pnl` | Profit/Loss (USDT) | 盈亏 (USDT) |
| `totalAnnRate` | Annualized return (%) | 年化收益率 (%) |
| `investAmt` | Invested amount | 投入金额 |
| `upl` | Unrealized P&L | 未实现盈亏 |
| `fillSafetyOrds` | Safety orders filled | 已触发补仓次数 |
| `minPx` / `maxPx` | Grid range (lower / upper) | 网格区间（下限 / 上限） |
| `tpPx` / `slPx` | Take-profit / Stop-loss price | 止盈价 / 止损价 |
| `avgPx` | Average entry price | 平均开仓价 |

## Global Notes

- This skill is **read-only** — it never creates, modifies, or stops bots
- All data is fetched from OKX servers in real time — results reflect current bot state
- `--profile <name>` is required for all commands; see "Credential & Profile Check" section
- Every response includes a `[profile: <name>]` tag for audit reference
- Rate limit: 20 requests per 2 seconds per UID for bot endpoints
- For large portfolios (>10 bots), fetch details sequentially to avoid rate limits
- `--json` flag can be added to any underlying command for raw API data
