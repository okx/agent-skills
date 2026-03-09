---
name: okx-cex-bot
description: "This skill should be used when the user asks to 'start a grid bot', 'create a grid bot', 'stop the grid bot', 'show my grid bots', 'grid bot status', 'grid bot P&L', 'create a DCA bot', 'start a DCA bot', 'dollar cost average into BTC', 'set up a martingale bot', 'show my DCA bots', 'stop the DCA bot', 'DCA P&L', or any request involving creating, stopping, querying, or monitoring grid or DCA (Dollar Cost Averaging / Martingale) bots on OKX CEX. Grid and DCA each cover both spot and contract variants. Requires API credentials. Do NOT use for regular spot/swap/futures orders (use okx-cex-trade), market data (use okx-cex-market), or account balance/portfolio (use okx-cex-portfolio)."
license: MIT
metadata:
  author: okx
  version: "1.0.0"
  homepage: "https://www.okx.com"
  moltbot:
    emoji: "🤖"
    requires:
      bins: ["okx"]
    install:
      - id: npm
        kind: node
        package: "@okx_ai/okx-trade-cli"
        bins: ["okx"]
        label: "Install okx CLI (npm)"
---

# OKX CEX Bot Trading CLI

Grid and DCA (Dollar Cost Averaging / Martingale) trading bot management on OKX exchange. All grid and DCA bots in this skill are **native OKX platform bots** — they run server-side on OKX and do not require a locally running process. **Requires API credentials.**

## Prerequisites

1. Install `okx` CLI:
   ```bash
   npm install -g @okx_ai/okx-trade-cli
   ```

2. Configure credentials — **check first, then set up if missing**:

   ```bash
   okx config show   # shows configured profiles; api_key shows last 4 chars if set
   ```

   **If credentials are already configured** → proceed to step 3.

   **If not configured**, choose one of:

   **Option A — Interactive wizard** (run this yourself in terminal; preserves existing profiles):
   ```bash
   okx config init          # demo mode (opens browser → OKX demo API page)
   okx config init          # run again for live mode (creates a second profile)
   ```
   Creates `okx-demo` (demo) and/or `okx-prod` (live) profiles. Each run safely merges into the existing config file without overwriting other profiles.

   **Option B — Write config directly** (use when no config file exists yet; agent can do this if user provides credentials in chat):
   ```bash
   # Demo only
   mkdir -p ~/.okx && cat > ~/.okx/config.toml << 'EOF'
   default_profile = "okx-demo"

   [profiles.okx-demo]
   api_key = "YOUR_API_KEY"
   secret_key = "YOUR_SECRET_KEY"
   passphrase = "YOUR_PASSPHRASE"
   demo = true
   EOF

   # Demo + live (both profiles)
   mkdir -p ~/.okx && cat > ~/.okx/config.toml << 'EOF'
   default_profile = "okx-demo"

   [profiles.okx-demo]
   api_key = "DEMO_API_KEY"
   secret_key = "DEMO_SECRET_KEY"
   passphrase = "DEMO_PASSPHRASE"
   demo = true

   [profiles.okx-prod]
   api_key = "PROD_API_KEY"
   secret_key = "PROD_SECRET_KEY"
   passphrase = "PROD_PASSPHRASE"
   demo = false
   EOF
   ```
   > ⚠ If `~/.okx/config.toml` already exists with other profiles, use Option A (`okx config init`) instead to avoid overwriting them.

   **After writing config**: CLI commands pick up the new credentials immediately. MCP tools require a reconnect (restart Claude Desktop or the MCP server process) to reload the config.

   **Switch between profiles**:
   ```bash
   okx config set default_profile okx-demo   # switch to demo
   okx config set default_profile okx-prod   # switch to live
   okx --profile okx-prod bot grid orders --algoOrdType grid  # one-off override
   ```

3. Test with demo mode (simulated trading, no real funds):
   ```bash
   okx --profile demo bot grid orders --algoOrdType grid
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
| `live` | 实盘 | Real funds — bot operates with real money |
| `demo` | 模拟盘 | Simulated — safe for testing bot configurations |

**Resolution rules:**
1. Current message intent is clear (e.g. "real" / "实盘" / "live" → `live`; "test" / "模拟" / "demo" → `demo`) → use it and inform the user: `"Using --profile live (实盘)"` or `"Using --profile demo (模拟盘)"`
2. Current message has no explicit declaration → check conversation context for a previous profile:
   - Found → use it, inform user: `"Continuing with --profile live (实盘) from earlier"`
   - Not found → ask: `"Live (实盘) or Demo (模拟盘)?"` — wait for answer before proceeding

### Handling 401 Authentication Errors

If any command returns a 401 / authentication error:
1. **Stop immediately** — do not retry the same command
2. Inform the user: "Authentication failed (401). Your API credentials may be invalid or expired."
3. Guide the user to update credentials by editing the file directly with their local editor:
   ```
   ~/.okx/config.toml
   ```
   Update the fields `api_key`, `secret_key`, `passphrase` under the relevant profile.
   Do NOT paste the new credentials into chat.
4. After the user confirms the file is updated, run `okx config show` to verify (output is masked)
5. Only then retry the original operation

## Demo vs Live Mode

Profile is the single control for 实盘/模拟盘 switching — exactly two options:

| `--profile` | Mode | Funds |
|---|---|---|
| `live` | 实盘 | Real funds — bot operates with real money |
| `demo` | 模拟盘 | Simulated — no real funds |

```bash
okx --profile live  bot grid create ...    # 实盘 — real funds
okx --profile demo  bot grid create ...    # 模拟盘 — simulated funds
```

**Rules:**
1. `--profile` is **required** on every authenticated command — determined in "Credential & Profile Check" Step B
2. Every response after a command must append: `[profile: live]` or `[profile: demo]`
3. Do **not** use the `--demo` flag for mode switching — use `--profile` instead
4. For bot create/stop operations (write commands), **profile must be explicitly confirmed** before execution

### Example

```
User: "Start a BTC grid bot"
Agent: "Live (实盘) or Demo (模拟盘)?"
User: "Demo"
Agent runs: okx --profile demo bot grid create --instId BTC-USDT --algoOrdType grid ...
Agent replies: "Grid bot created: 12345678 (OK) — simulated, no real funds used. [profile: demo]"
```

## Skill Routing

- For market data (prices, charts, depth, funding rates) → use `okx-cex-market`
- For account balance, P&L, positions history, fees, transfers → use `okx-cex-portfolio`
- For regular spot/swap/futures/algo orders → use `okx-cex-trade`
- For grid and DCA trading strategies (native OKX platform bots) → use `okx-cex-bot` (this skill)

## Quickstart

```bash
# Create a spot grid bot on BTC ($90k–$100k, 10 grids, invest 1000 USDT)
okx bot grid create --instId BTC-USDT --algoOrdType grid \
  --minPx 90000 --maxPx 100000 --gridNum 10 --quoteSz 1000

# Create a contract grid bot on BTC perp (neutral, 5x leverage, 100 USDT margin)
# basePos defaults to true for long/short (opens base position); neutral ignores it
okx bot grid create --instId BTC-USDT-SWAP --algoOrdType contract_grid \
  --minPx 90000 --maxPx 100000 --gridNum 10 \
  --direction neutral --lever 5 --sz 100

# List all active grid bots
okx bot grid orders --algoOrdType grid

# Get grid bot details and P&L
okx bot grid details --algoOrdType grid --algoId <algoId>

# Stop a grid bot (keep assets as-is)
okx bot grid stop --algoId <algoId> --algoOrdType grid --instId BTC-USDT --stopType 2

# Create a DCA bot on BTC (3% TP, 5% SL, 3 safety orders, each triggers at 5% drop)
okx bot dca create --instId BTC-USDT \
  --initOrdAmt 50 --safetyOrdAmt 30 --maxSafetyOrds 3 \
  --pxSteps 0.05 --pxStepsMult 1 --volMult 1 \
  --tpPct 0.03 --slPct 0.05 --triggerType 1

# List all active spot DCA bots
okx bot dca orders

# Get DCA bot details
okx bot dca details --algoId <algoId>

# Stop a DCA bot (sell base and get quote)
okx bot dca stop --algoId <algoId> --instId BTC-USDT --stopType 1
```

## Command Index

### Grid Bot

| # | Command | Type | Description |
|---|---|---|---|
| 1 | `okx bot grid create` | WRITE | Create a grid bot |
| 2 | `okx bot grid stop` | WRITE | Stop a grid bot |
| 3 | `okx bot grid orders` | READ | List active or history grid bots |
| 4 | `okx bot grid details` | READ | Single grid bot details + PnL |
| 5 | `okx bot grid sub-orders` | READ | Individual grid fills or live orders |

### DCA Bot

| # | Command | Type | Description |
|---|---|---|---|
| 6 | `okx bot dca create` | WRITE | Create a DCA bot (spot or contract) |
| 7 | `okx bot dca stop` | WRITE | Stop a DCA bot (spot or contract) |
| 8 | `okx bot dca orders` | READ | List active or history DCA bots |
| 9 | `okx bot dca details` | READ | Single DCA bot details + PnL |
| 10 | `okx bot dca sub-orders` | READ | Individual DCA fills, live orders, or cycles |

> Use `--type spot` (default) or `--type contract` to switch between spot and contract DCA.

## Cross-Skill Workflows

### Spot Grid Bot
> User: "Start a BTC grid bot between $90k and $100k with 10 grids, invest 1000 USDT"

```
1. okx-cex-market    okx market ticker BTC-USDT                     → confirm price is in range
2. okx-cex-portfolio okx account balance USDT                       → confirm available funds
        ↓ user approves
3. okx-cex-bot       okx bot grid create --instId BTC-USDT --algoOrdType grid \
                       --minPx 90000 --maxPx 100000 --gridNum 10 --quoteSz 1000
4. okx-cex-bot       okx bot grid orders --algoOrdType grid          → confirm bot is active
5. okx-cex-bot       okx bot grid details --algoOrdType grid --algoId <id> → monitor PnL
```

### Contract Grid Bot (Long / Short / Neutral)
> User: "Create a long grid bot on BTC perp from $90k to $100k, 10x leverage"

```
1. okx-cex-market    okx market ticker BTC-USDT-SWAP                → confirm current price
2. okx-cex-portfolio okx account balance USDT                       → confirm margin
        ↓ user approves
3. okx-cex-bot       okx bot grid create --instId BTC-USDT-SWAP --algoOrdType contract_grid \
                       --minPx 90000 --maxPx 100000 --gridNum 10 \
                       --direction long --lever 10 --sz 100
                       # basePos defaults to true (opens base position for long/short)
                       # For short: --direction short; for neutral: --direction neutral
4. okx-cex-bot       okx bot grid orders --algoOrdType contract_grid → confirm active
```

### Spot DCA Bot
> User: "Set up a DCA bot on ETH, initial buy $100, 5 safety orders at 3% drops, 2% TP"

```
1. okx-cex-market    okx market ticker ETH-USDT                     → check current price
2. okx-cex-portfolio okx account balance USDT                       → confirm funds available
        ↓ user approves
3. okx-cex-bot       okx bot dca create --instId ETH-USDT \
                       --initOrdAmt 100 --safetyOrdAmt 50 --maxSafetyOrds 5 \
                       --pxSteps 0.03 --pxStepsMult 1 --volMult 1 \
                       --tpPct 0.02 --slPct 0.05 --triggerType 1
4. okx-cex-bot       okx bot dca orders                             → confirm bot is active
5. okx-cex-bot       okx bot dca details --algoId <id>              → monitor PnL
```

### Contract DCA Bot (Long / Short)
> User: "Start a short DCA bot on BTC perp, 3x leverage, $200 initial, 3% TP"

```
1. okx-cex-market    okx market ticker BTC-USDT-SWAP               → confirm current price
2. okx-cex-portfolio okx account balance USDT                       → confirm margin
        ↓ user approves
3. okx-cex-bot       okx bot dca create --type contract --instId BTC-USDT-SWAP \
                       --initOrdAmt 200 --safetyOrdAmt 100 --maxSafetyOrds 3 \
                       --pxSteps 0.03 --pxStepsMult 1.2 --volMult 1.5 \
                       --tpPct 0.03 --lever 3 --direction short
                       # For long: --direction long
4. okx-cex-bot       okx bot dca orders --type contract             → confirm active
5. okx-cex-bot       okx bot dca details --type contract --algoId <id> → monitor PnL
```

### Monitor and Stop All Bots
> User: "Show all my active bots and stop the ones losing money"

```
1. okx-cex-bot       okx bot grid orders --algoOrdType grid         → list spot grid bots
2. okx-cex-bot       okx bot grid orders --algoOrdType contract_grid → list contract grid bots
3. okx-cex-bot       okx bot dca orders [--type contract]           → list DCA bots
4. okx-cex-bot       okx bot grid details --algoOrdType grid --algoId <id>  → check PnL
5. okx-cex-bot       okx bot grid stop --algoId <id> --algoOrdType grid --instId BTC-USDT --stopType 2
```

## Operation Flow

### Step 0 — Credential & Profile Check

Before any authenticated command:

**Determine profile (required):**
- Options: `live` (实盘) or `demo` (模拟盘) — exactly these two values
1. Current message intent clear (e.g. "real"/"实盘"/"live" → live; "test"/"模拟"/"demo" → demo) → use it, inform user: `"Using --profile live (实盘)"`
2. Current message has no explicit declaration → check conversation context for previous profile:
   - Found → use it, inform user: `"Continuing with --profile live (实盘) from earlier"`
   - Not found → ask: `"Live (实盘) or Demo (模拟盘)?"` — wait for answer

**If no credentials configured:** guide user to run `okx config init`, stop all trading actions

**After every command result:** append `[profile: live]` or `[profile: demo]` to the response

### Step 1: Identify Bot Type and Action

- Grid bot create → `okx bot grid create`
- Grid bot stop → `okx bot grid stop`
- Grid bot status/P&L → `okx bot grid orders` + `okx bot grid details`
- Grid individual fills → `okx bot grid sub-orders`
- DCA bot create → `okx bot dca create` (add `--type contract` for contract DCA)
- DCA bot stop → `okx bot dca stop` (add `--type contract` for contract DCA)
- DCA bot status/P&L → `okx bot dca orders` + `okx bot dca details`
- DCA individual fills/cycles → `okx bot dca sub-orders`

### Step 2: Run Read Commands Immediately — Confirm Profile (Step 0) then Writes

**Read commands** (orders, details, sub-orders): run immediately.

- `--algoOrdType` for grid → infer from context (`grid` for spot, `contract_grid` for perp)
- `--type` for DCA → defaults to `spot`; use `--type contract` for contract DCA
- `--history` → use default (active); only query history if explicitly requested

**Write commands** (create, stop): confirm once before executing.

- Grid create: confirm `--minPx`, `--maxPx`, `--gridNum`; verify `--minPx` < current price < `--maxPx`; confirm investment size
    - Spot grid: `--quoteSz` (USDT) or `--baseSz` (base currency)
    - Contract grid: `--direction` (`long`/`short`/`neutral`), `--lever`, `--sz` (investment margin in USDT); `--basePos` defaults to `true` (open base position for long/short)
- DCA create: confirm `--initOrdAmt`, `--safetyOrdAmt`, `--maxSafetyOrds`, `--pxSteps`, `--tpPct`
    - Spot DCA: requires `--triggerType` (`1`=instant, `2`=RSI); default `--type spot`
    - Contract DCA: add `--type contract`, `--lever`, and `--direction` (`long`/`short`)
- Grid stop: confirm `--stopType` (default omitted → keep assets; `1`=sell all to quote)
- DCA stop: confirm `--stopType` (`1`=sell base to quote, default; `2`=keep base)
- Demo dry-run: suggest `okx --profile demo bot grid create ...` when user is unsure

**⚠ Insufficient balance — NEVER auto-transfer funds.**
If the trading account balance is insufficient to create a bot, do NOT automatically initiate a fund transfer (`account_transfer`). Instead, inform the user of the shortfall (current available vs. required amount) and ask how they want to proceed. Suggested options to present:
1. Transfer funds from funding account to trading account (specify amount)
2. Reduce the investment size to fit available balance
3. Cancel the bot creation

### Step 3: Verify After Writes

- After grid create: run `okx bot grid orders` to confirm bot is active; then `okx bot grid details` to monitor PnL
- After DCA create: run `okx bot dca orders` to confirm bot is active; then `okx bot dca details` for details
- After stop: run `okx bot grid orders --history` / `okx bot dca orders --history` to confirm bot is stopped

## CLI Command Reference

### Grid Bot — Create

```bash
okx bot grid create --instId <id> --algoOrdType <type> \
  --maxPx <px> --minPx <px> --gridNum <n> \
  [--runType <1|2>] \
  [--quoteSz <n>] [--baseSz <n>] \
  [--direction <long|short|neutral>] [--lever <n>] [--sz <n>] \
  [--basePos] [--no-basePos] \
  [--json]
```

| Param | Required | Default | Description |
|---|---|---|---|
| `--instId` | Yes | - | Instrument (e.g., `BTC-USDT` for spot grid, `BTC-USDT-SWAP` for contract grid) |
| `--algoOrdType` | Yes | - | `grid` (spot grid) or `contract_grid` (contract grid) |
| `--maxPx` | Yes | - | Upper price boundary |
| `--minPx` | Yes | - | Lower price boundary |
| `--gridNum` | Yes | - | Grid levels (2–100) |
| `--runType` | No | `1` | `1`=arithmetic spacing, `2`=geometric spacing |
| `--quoteSz` | Cond. | - | USDT investment — spot grid only (provide `quoteSz` or `baseSz`) |
| `--baseSz` | Cond. | - | Base currency investment — spot grid only |
| `--direction` | Cond. | - | `long`, `short`, or `neutral` — contract grid only |
| `--lever` | Cond. | - | Leverage (e.g., `5`) — contract grid only |
| `--sz` | Cond. | - | Investment margin in USDT — contract grid only |
| `--basePos` / `--no-basePos` | No | `true` | Open a base position at creation — contract grid only (ignored for neutral direction). Default is `true` (opens base position). Use `--no-basePos` to disable. |

---

### Grid Bot — Stop

```bash
okx bot grid stop --algoId <id> --algoOrdType <type> --instId <id> \
  [--stopType <1|2|3|5|6>] [--json]
```

| `--stopType` | Behavior |
|---|---|
| `1` | Stop + sell/close all positions at market |
| `2` | Stop + keep current assets as-is (default) |
| `3` | Stop + close at limit prices |
| `5` | Stop + partial close |
| `6` | Stop without selling (smart arbitrage) |

---

### Grid Bot — List Orders

```bash
okx bot grid orders --algoOrdType <type> [--instId <id>] [--algoId <id>] [--history] [--json]
```

| Param | Required | Default | Description |
|---|---|---|---|
| `--algoOrdType` | Yes | - | `grid` or `contract_grid` |
| `--instId` | No | - | Filter by instrument |
| `--algoId` | No | - | Filter by algo ID |
| `--history` | No | false | Show completed/stopped bots instead of active |

---

### Grid Bot — Details

```bash
okx bot grid details --algoOrdType <type> --algoId <id> [--json]
```

Returns: bot config, current PnL (`pnlRatio`), grid range, number of grids, state, position info.

---

### Grid Bot — Sub-Orders

```bash
okx bot grid sub-orders --algoOrdType <type> --algoId <id> [--live] [--json]
```

| Flag | Effect |
|---|---|
| *(default)* | Filled sub-orders (executed grid trades) |
| `--live` | Pending grid orders currently on the book |

---

### DCA Bot — Create

```bash
# Spot DCA (default)
okx bot dca create --instId <id> \
  --initOrdAmt <n> --safetyOrdAmt <n> --maxSafetyOrds <n> \
  --pxSteps <ratio> --pxStepsMult <mult> --volMult <mult> \
  --tpPct <ratio> --slPct <ratio> \
  --triggerType <1|2> \
  [--reserveFunds <true|false>] [--json]

# Contract DCA
okx bot dca create --type contract --instId <id> \
  --initOrdAmt <n> --maxSafetyOrds <n> --tpPct <ratio> \
  --lever <n> --direction <long|short> \
  [--safetyOrdAmt <n>] [--pxSteps <ratio>] [--pxStepsMult <mult>] [--volMult <mult>] \
  [--slPct <ratio>] [--slMode <limit|market>] [--allowReinvest <true|false>] \
  [--triggerStrategy <instant|price|rsi>] [--triggerPx <price>] [--json]
```

| Param | Required | Default | Description |
|---|---|---|---|
| `--type` | No | `spot` | `spot` or `contract` |
| `--instId` | Yes | - | Instrument (e.g., `BTC-USDT` for spot, `BTC-USDT-SWAP` for contract) |
| `--initOrdAmt` | Yes | - | Initial order amount (quote currency) |
| `--safetyOrdAmt` | Spot: Yes, Contract: No | - | Safety order amount (quote currency) |
| `--maxSafetyOrds` | Yes | - | Max number of safety orders (e.g., `3`; contract: `0` = no DCA) |
| `--pxSteps` | Spot: Yes, Contract: No | - | Initial price deviation percentage (e.g., `0.03` = 3%) |
| `--pxStepsMult` | Spot: Yes, Contract: No | - | Price step multiplier between safety orders (e.g., `1.2`) |
| `--volMult` | Spot: Yes, Contract: No | - | Safety order size multiplier (e.g., `1.5`) |
| `--tpPct` | Yes | - | Take-profit ratio (e.g., `0.03` = 3%) |
| `--slPct` | Spot: Yes, Contract: No | - | Stop-loss ratio (e.g., `0.05` = 5%) |
| `--reserveFunds` | Spot only | `false` | Pre-reserve full required assets upfront (not applicable for contract) |
| `--triggerType` | Spot only | - | `1`=instant start, `2`=RSI signal trigger (RSI params not currently supported) |
| `--lever` | Contract only | - | Leverage multiplier (e.g., `3`) |
| `--direction` | Contract only | - | `long` or `short` (spot is always `long`) |
| `--slMode` | Contract only | `market` | Stop-loss price type: `limit` (limit price) or `market` (market price) |
| `--allowReinvest` | Contract only | `true` | Reinvest profit into the next DCA cycle |
| `--triggerStrategy` | Contract only | `instant` | How the bot starts: `instant`, `price` (wait for trigger price), or `rsi` (RSI signal) |
| `--triggerPx` | Contract only | - | Trigger price — required when `triggerStrategy=price` |

---

### DCA Bot — Stop

```bash
# Spot DCA (requires instId and stopType)
okx bot dca stop --algoId <id> --instId <id> --stopType <1|2> [--json]

# Contract DCA (only algoId needed)
okx bot dca stop --type contract --algoId <id> [--json]
```

| Param | Spot | Contract | Description |
|---|---|---|---|
| `--algoId` | Required | Required | Strategy id |
| `--instId` | Required | Not used | Instrument ID, e.g. BTC-USDT |
| `--stopType` | Required | Not used | `1`=stop & sell base to quote; `2`=stop without sell |

---

### DCA Bot — List Orders

```bash
okx bot dca orders [--type <spot|contract>] [--history] [--instId <id>] [--json]
```

| Param | Required | Default | Description |
|---|---|---|---|
| `--type` | No | `spot` | `spot` or `contract` |
| `--history` | No | false | Show completed/stopped bots instead of active |
| `--instId` | No | - | [contract only] Filter by instrument, e.g. `BTC-USDT-SWAP` |

---

### DCA Bot — Details

```bash
okx bot dca details [--type <spot|contract>] --algoId <id> [--json]
```

Returns: Spot — bot config, current PnL (`pnlRatio`), safety orders triggered, state. Contract — position details including `avgPx`, `upl`, `liqPx`, `sz`, `tpPx`, `slPx`, `initPx`, `fundingFee`, `fee`, `fillSafetyOrds`.

---

### DCA Bot — Sub-Orders

```bash
okx bot dca sub-orders [--type <spot|contract>] --algoId <id> [--live] [--cycleId <id>] [--json]
```

| Flag / Param | Effect |
|---|---|
| *(default, spot)* | Filled sub-orders (executed DCA buys) |
| `--live` | Spot: pending orders currently on the book |
| `--cycleId <id>` | Spot: optional filter by cycle. Contract: show orders within a specific cycle (omit to list all cycles) |
| *(default, contract)* | List all cycles |

---

## MCP Tool Reference

CLI and MCP tools share the same underlying tool layer. MCP tools accept `type=spot` or `type=contract` directly.

| Tool | Description |
|---|---|
| `dca_create_order` | Create spot or contract DCA bot |
| `dca_stop_order` | Stop spot or contract DCA bot |
| `dca_get_orders` | List spot or contract DCA bots |
| `dca_get_order_details` | Single DCA bot details |
| `dca_get_sub_orders` | Sub-orders (spot) or cycles (contract) |

---

## Input / Output Examples

**"Start a BTC grid bot from $90k to $100k with 10 grids"**
```bash
okx bot grid create --instId BTC-USDT --algoOrdType grid \
  --minPx 90000 --maxPx 100000 --gridNum 10 --quoteSz 1000
# → Grid bot created: 12345678 (OK)
```

**"Show all my active grid bots"**
```bash
okx bot grid orders --algoOrdType grid
```

**"What's the P&L on my BTC grid bot?"**
```bash
okx bot grid details --algoOrdType grid --algoId 12345678
# → pnlRatio, pnl, investAmt, totalAnnRate, runType, gridNum, maxPx, minPx
```

**"Stop my BTC grid bot and keep the assets"**
```bash
okx bot grid stop --algoId 12345678 --algoOrdType grid --instId BTC-USDT --stopType 2
```

**"Create a DCA bot on ETH: $100 initial, safety orders at 3% drops, 2% TP, 5% SL"**
```bash
okx bot dca create --instId ETH-USDT \
  --initOrdAmt 100 --safetyOrdAmt 50 --maxSafetyOrds 3 \
  --pxSteps 0.03 --pxStepsMult 1 --volMult 1 \
  --tpPct 0.02 --slPct 0.05 --triggerType 1
# → DCA bot created: 87654321 (OK)
```

**"Show my active DCA bots"**
```bash
okx bot dca orders
```

**"How is my ETH DCA bot doing?"**
```bash
okx bot dca details --algoId 87654321
# → current PnL, avg entry, safety orders triggered, TP target
```

**"Stop my ETH DCA bot and sell everything"**
```bash
okx bot dca stop --algoId 87654321 --instId ETH-USDT --stopType 1
```

**"Create a contract DCA bot on BTC perp, long, 3x leverage, 2% TP, 15% SL"**
```bash
okx bot dca create --type contract --instId BTC-USDT-SWAP \
  --initOrdAmt 200 --safetyOrdAmt 100 --maxSafetyOrds 3 \
  --pxSteps 0.03 --pxStepsMult 1.2 --volMult 1.5 \
  --tpPct 0.02 --lever 3 --direction long
```

## Edge Cases

### Grid Bot

- **Price out of range**: `--minPx` must be < current price < `--maxPx`; check with `okx-cex-market` first
- **Insufficient balance**: check `okx-cex-portfolio` → `account balance` before creating. If insufficient, **do NOT auto-transfer** — report the shortfall and ask the user for instructions (see Step 2)
- **Contract grid direction**: `long` (buys more at lower prices), `short` (sells at higher), `neutral` (both)
- **Contract grid basePos**: defaults to `true` — long/short grids automatically open a base position at creation. Neutral direction ignores this. Pass `--no-basePos` to disable.
- **Contract grid --sz**: investment margin in USDT (not number of contracts)
- **Stop type**: `stopType 1` sells/closes all; `stopType 2` keeps assets; `stopType 5/6` for contract grid positions
- **Already stopped bot**: stop returns error — check `bot grid orders --history` first to confirm state
- **Demo mode**: `okx --profile demo bot grid create ...` — safe for testing, no real funds

### DCA Bot

- **Insufficient balance**: check `okx-cex-portfolio` → `account balance` before creating. If insufficient, **do NOT auto-transfer** — report the shortfall and ask the user for instructions (see Step 2)
- **pxStepsMult**: use `1.0` for equal price spacing; `>1.0` to widen gaps between successive safety orders
- **volMult**: use `1.0` for equal safety order sizes; `>1.0` to increase size per safety order (Martingale)
- **triggerType 2 (RSI)**: RSI trigger parameters are not currently supported in the CLI/MCP tools — always use `1` (instant)
- **Stop type (spot only)**: `stopType 1` sells base to quote (cash out); `stopType 2` keeps base currency as-is. Contract DCA stop does not use `instId` or `stopType`.
- **Already stopped bot**: stop returns error — check `bot dca orders --history` first to confirm state
- **Contract DCA**: add `--type contract` to any DCA CLI command; create also requires `--lever` and `--direction` (`long`/`short`)

## Communication Guidelines

- **Use "bot" not "strategy"** when referring to grid or DCA in user-facing responses (e.g., "grid bot", "DCA bot" — not "grid strategy" or "DCA strategy").
- **Always refer to DCA bots as "DCA"** — do not translate to "定投" or "recurring buy". The underlying mechanism is Martingale (马丁格尔), not simple dollar cost averaging. Use "DCA" in all user-facing responses regardless of language.
- **Grid bot** can be referred to as "网格" in Chinese contexts.

### Parameter Display Names

When communicating with users, use the display name instead of the raw API field name. The API field is for internal mapping only.

> **Currency placeholders**: `{base}` and `{quote}` refer to the actual currencies from the trading pair. Extract them by splitting `instId` on `-`: for `BTC-USDT` → base=BTC, quote=USDT; for `ETH-USDC` → base=ETH, quote=USDC; for `BTC-USDT-SWAP` → base=BTC, quote=USDT (ignore the SWAP suffix).

#### Grid Bot — Spot (`algoOrdType=grid`)

| API Field | Display Name (EN) | Display Name (ZH) |
|---|---|---|
| `instId` | Trading pair | 交易对 |
| `minPx` | Lower price bound | 网格下限价格 |
| `maxPx` | Upper price bound | 网格上限价格 |
| `gridNum` | Number of grids | 网格数量 |
| `quoteSz` | Investment amount ({quote}) | 投入金额（{quote}） |
| `baseSz` | Investment amount ({base}) | 投入金额（{base}） |
| `runType` | Spacing mode (1=arithmetic, 2=geometric) | 网格间距模式（1=等差, 2=等比） |
| `stopType` | Stop behavior | 停止方式 |

#### Grid Bot — Contract (`algoOrdType=contract_grid`)

| API Field | Display Name (EN) | Display Name (ZH) |
|---|---|---|
| `instId` | Trading pair | 交易对 |
| `minPx` | Lower price bound | 网格下限价格 |
| `maxPx` | Upper price bound | 网格上限价格 |
| `gridNum` | Number of grids | 网格数量 |
| `sz` | Investment margin ({quote}) | 投入保证金（{quote}） |
| `direction` | Direction (long / short / neutral) | 方向（做多 / 做空 / 中性） |
| `lever` | Leverage | 杠杆倍数 |
| `runType` | Spacing mode (1=arithmetic, 2=geometric) | 网格间距模式（1=等差, 2=等比） |
| `basePos` | Open base position | 是否开底仓 |
| `stopType` | Stop behavior | 停止方式 |

#### DCA Bot — Spot (default)

| API Field | Display Name (EN) | Display Name (ZH) |
|---|---|---|
| `instId` | Trading pair | 交易对 |
| `initOrdAmt` | Initial order amount ({quote}) | 首单金额（{quote}） |
| `safetyOrdAmt` | Safety order amount ({quote}) | 补仓金额（{quote}） |
| `maxSafetyOrds` | Max safety orders | 最大补仓次数 |
| `pxSteps` | Price drop per safety order (%) | 补仓价格跌幅（%） |
| `pxStepsMult` | Price step multiplier | 补仓跌幅倍数 |
| `volMult` | Safety order size multiplier | 补仓金额倍数 |
| `tpPct` | Take-profit ratio (%) | 止盈比例（%） |
| `slPct` | Stop-loss ratio (%) | 止损比例（%） |
| `slMode` | Stop-loss type (limit / market) | 止损类型（限价 / 市价） |
| `triggerType` | Trigger mode (1=instant, 2=RSI) | 触发方式（1=立即, 2=RSI 信号） |
| `reserveFunds` | Reserve full assets upfront | 是否预留全部资金 |

> **`slPct` stop-loss logic (spot DCA)**: Stop-loss price = initial order fill price × (1 − slPct). When the stop-loss price is triggered and the position is fully closed, the bot ends.

#### DCA Bot — Contract (`--type contract`)

| API Field | Display Name (EN) | Display Name (ZH) |
|---|---|---|
| `instId` | Trading pair | 交易对 |
| `initOrdAmt` | Initial margin ({quote}) | 首单保证金（{quote}） |
| `safetyOrdAmt` | Safety order margin ({quote}) | 补仓保证金（{quote}） |
| `maxSafetyOrds` | Max safety orders | 最大补仓次数 |
| `pxSteps` | Price drop per safety order (%) | 补仓价格跌幅（%） |
| `pxStepsMult` | Price step multiplier | 补仓跌幅倍数 |
| `volMult` | Safety order size multiplier | 补仓金额倍数 |
| `tpPct` | Take-profit ratio (%) | 止盈比例（%） |
| `slPct` | Stop-loss ratio (%) | 止损比例（%） |
| `slMode` | Stop-loss type (limit / market) | 止损类型（限价 / 市价） |
| `lever` | Leverage | 杠杆倍数 |
| `side` | Direction (buy=long, sell=short) | 方向（buy=做多, sell=做空） |
| `reserveFunds` | Reserve full assets upfront | 是否预留全部资金 |

> **`slPct` stop-loss logic (contract DCA)**:
> - Long (`side=buy`): stop-loss price = initial order fill price × (1 − slPct)
> - Short (`side=sell`): stop-loss price = initial order fill price × (1 + slPct)
>
> When the stop-loss price is triggered and the position is fully closed, the bot ends.
>

### Interaction Rules

When collecting parameters from the user, always use natural language — never expose raw API field names.

- Ask "What price range for the grid? (lower ~ upper)" — not "Enter minPx and maxPx"
- Ask "How many grids?" — not "Enter gridNum"
- Spot: ask "How much to invest (USDT)?" (use the actual quote currency) — not "Enter quoteSz"
- Contract: ask "How much margin to invest (USDT)?" (use the actual quote currency) — not "Enter sz"
- Ask "What leverage?" — not "Enter lever"
- Ask "Take-profit target (%)?" — not "Enter tpPct"
- Ask "How many safety orders at most?" — not "Enter maxSafetyOrds"

If the user already provides values in their initial request, do not re-ask — map them directly to the corresponding API fields.

## Global Notes

- Grid and DCA bots are native OKX platform bots — they run entirely on OKX servers; stopping the CLI does not affect them
- All write commands require valid credentials in `~/.okx/config.toml` or env vars
- `--profile <name>` is required for all authenticated commands; see "Credential & Profile Check" section
- Every command result includes a `[profile: <name>]` tag for audit reference
- `--json` returns raw OKX API v5 response
- Rate limit: 20 requests per 2 seconds per UID for all bot operations
- Grid `--gridNum` range: 2–100
- DCA safety orders are triggered sequentially as price drops by `--pxSteps` increments
- Contract DCA automatically starts with an instant trigger (set by the tool internally)
