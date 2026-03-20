---
name: okx-cex-market
description: "This skill should be used when the user asks for 'price of BTC', 'ETH ticker', 'show me the orderbook', 'market depth', 'BTC candles', 'OHLCV chart data', 'funding rate', 'open interest', 'mark price', 'index price', 'recent trades', 'price limit', 'list instruments', 'what instruments are available', or any request to query public market data on OKX CEX. Also use this skill for technical indicator queries: 'RSI', 'MACD', 'EMA', 'MA', 'Bollinger Bands', 'KDJ', 'SuperTrend', 'AHR999', 'BTC rainbow', 'pi-cycle', 'Mayer Multiple', 'is BTC overbought', 'trend analysis', 'entry signal', 'BTC cycle'. All commands are read-only and do NOT require API credentials. Do NOT use for account balance/positions (use okx-cex-portfolio), placing/cancelling orders (use okx-cex-trade), or grid/DCA bots (use okx-cex-bot)."
license: MIT
metadata:
  author: okx
  version: "1.0.0"
  homepage: "https://www.okx.com"
  agent:
    requires:
      bins: ["okx"]
    install:
      - id: npm
        kind: node
        package: "@okx_ai/okx-trade-cli"
        bins: ["okx"]
        label: "Install okx CLI (npm)"
---

# OKX CEX Market Data CLI

Public market data for OKX exchange: prices, order books, candles, funding rates, open interest, instrument info, and **technical indicators** (RSI, MACD, EMA, Bollinger Bands, SuperTrend, AHR999, BTC Rainbow, and more). All commands are **read-only** and do **not require API credentials**.

## Prerequisites

1. Install `okx` CLI:
   ```bash
   npm install -g @okx_ai/okx-trade-cli
   ```
2. No credentials needed for market data — all commands are public.
3. Verify install:
   ```bash
   okx market ticker BTC-USDT
   ```

## Demo vs Live Mode

Market data commands are public and read-only — **demo mode has no effect**. The same data is returned with or without `--demo`. No confirmation needed before running any market command.

## Skill Routing

- For market data (prices, charts, depth, funding rates) → use `okx-cex-market` (this skill)
- For technical indicators (RSI, MACD, EMA, BB, KDJ, SuperTrend, AHR999, Rainbow, etc.) → use `okx-cex-market` (this skill, `okx market indicator`)
- For account balance, P&L, positions, fees, transfers → use `okx-cex-portfolio`
- For regular spot/swap/futures/algo orders → use `okx-cex-trade`
- For grid and DCA trading bots → use `okx-cex-bot`

## Quickstart

```bash
# Current BTC spot price
okx market ticker BTC-USDT

# All SWAP (perp) tickers
okx market tickers SWAP

# BTC perp order book (top 5 levels each side)
okx market orderbook BTC-USDT-SWAP

# BTC hourly candles (last 20)
okx market candles BTC-USDT --bar 1H --limit 20

# BTC perp current funding rate
okx market funding-rate BTC-USDT-SWAP

# BTC perp funding rate history
okx market funding-rate BTC-USDT-SWAP --history

# Open interest for all SWAP instruments
okx market open-interest --instType SWAP

# List all active SPOT instruments
okx market instruments --instType SPOT

# List all tradeable stock token perpetuals (TSLA, NVDA, AAPL, etc.)
okx market stock-tokens

# BTC 4H RSI (latest value)
okx market indicator rsi BTC-USDT --bar 4H --params 14

# BTC/USDT EMA 5 and EMA 20 on 1H (trend check)
okx market indicator ema BTC-USDT --bar 1H --params 5,20

# BTC MACD on daily
okx market indicator macd BTC-USDT --bar 1Dutc

# BTC macro cycle: AHR999 (no bar needed)
okx market indicator ahr999 BTC-USDT

# Historical RSI list (last 20 periods)
okx market indicator rsi BTC-USDT --bar 4H --params 14 --list --limit 20
```

## Command Index

| # | Command | Type | Description |
|---|---|---|---|
| 1 | `okx market ticker <instId>` | READ | Single instrument: last price, 24h high/low/vol |
| 2 | `okx market tickers <instType>` | READ | All tickers for an instrument type |
| 3 | `okx market instruments --instType <type>` | READ | List tradeable instruments |
| 4 | `okx market orderbook <instId> [--sz <n>]` | READ | Order book top asks/bids |
| 5 | `okx market candles <instId> [--bar] [--limit]` | READ | OHLCV candlestick data |
| 6 | `okx market index-candles <instId> [--bar] [--limit]` | READ | Index OHLCV candles |
| 7 | `okx market funding-rate <instId> [--history]` | READ | Current or historical funding rate |
| 8 | `okx market trades <instId> [--limit <n>]` | READ | Recent public trades |
| 9 | `okx market mark-price --instType <type> [--instId <id>]` | READ | Mark price for contracts |
| 10 | `okx market index-ticker [--instId <id>] [--quoteCcy <ccy>]` | READ | Index price (e.g., BTC-USD) |
| 11 | `okx market price-limit <instId>` | READ | Upper/lower price limits for contracts |
| 12 | `okx market open-interest --instType <type> [--instId <id>]` | READ | Open interest in contracts and coins |
| 13 | `okx market stock-tokens` | READ | List all tradeable stock token perpetuals (TSLA, NVDA, AAPL, etc.) |
| 14 | `okx market indicator <indicator> <instId> [--bar] [--params] [--list] [--limit]` | READ | Technical indicator value(s): MA, EMA, RSI, MACD, BB, KDJ, SuperTrend, AHR999, Rainbow, and more |

## Cross-Skill Workflows

### Check price before placing an order
> User: "What's the current BTC price? I want to place a limit buy."

```
1. okx-cex-market    okx market ticker BTC-USDT              → check last price and 24h range
        ↓ user decides price
2. okx-cex-portfolio okx account balance USDT                → confirm available funds
        ↓ user approves
3. okx-cex-trade     okx spot place --instId BTC-USDT --side buy --ordType limit --px <px> --sz <sz>
```

### Check funding rate before holding a perp position
> User: "Is the BTC perp funding rate high right now?"

```
1. okx-cex-market    okx market funding-rate BTC-USDT-SWAP   → current rate + next funding time
2. okx-cex-market    okx market funding-rate BTC-USDT-SWAP --history  → trend over recent periods
        ↓ decide whether to hold position
3. okx-cex-portfolio okx account positions                   → check existing exposure
```

### Research market before creating a grid bot
> User: "I want to set up a BTC grid bot — what's the recent range?"

```
1. okx-cex-market    okx market candles BTC-USDT --bar 4H --limit 50  → recent OHLCV for range
2. okx-cex-market    okx market ticker BTC-USDT                        → current price
3. okx-cex-market    okx market orderbook BTC-USDT --sz 20             → liquidity check
        ↓ decide minPx / maxPx
4. okx-cex-bot       okx bot grid create --instId BTC-USDT ...
```

### Compare perp vs spot premium
> User: "Is there a premium between BTC spot and BTC perp?"

```
1. okx-cex-market    okx market ticker BTC-USDT              → spot last price
2. okx-cex-market    okx market ticker BTC-USDT-SWAP         → perp last price
3. okx-cex-market    okx market mark-price --instType SWAP --instId BTC-USDT-SWAP  → mark price
```

### Discover stock tokens before trading
> User: "I want to trade TSLA or NVDA — what's available?"

```
1. okx-cex-market   okx market stock-tokens              → list all stock token instIds and specs
        ↓ pick instId (e.g., TSLA-USDT-SWAP)
2. okx-cex-market   okx market ticker TSLA-USDT-SWAP     → current price and 24h range
3. okx-cex-market   okx market instruments --instType SWAP --instId TSLA-USDT-SWAP --json
                    → get ctVal, minSz, lotSz for sz conversion
        ↓ ready to trade — see okx-cex-trade (max leverage: 5x)
```

---

### Trend analysis / entry signal
> User: "Is BTC in an uptrend? Good time to buy?"

```
1. okx-cex-market    okx market indicator ema BTC-USDT --bar 4H --params 5,20
                     → EMA5 vs EMA20: EMA5 > EMA20 = bullish alignment
2. okx-cex-market    okx market indicator supertrend BTC-USDT --bar 4H
                     → SuperTrend direction signal (buy / sell)
3. okx-cex-market    okx market indicator macd BTC-USDT --bar 4H
                     → MACD histogram and DIF/DEA crossover status
4. okx-cex-market    okx market ticker BTC-USDT
                     → confirm current price relative to key levels
        ↓ all signals aligned → proceed to trade
5. okx-cex-portfolio okx account balance USDT            → check available funds
6. okx-cex-trade     okx spot place --instId BTC-USDT --side buy --ordType market --sz <sz>
```

---

### Overbought / oversold — exit or take-profit timing
> User: "Is ETH overbought? Should I reduce my position?"

```
1. okx-cex-market    okx market indicator rsi ETH-USDT --bar 1H --params 14
                     → RSI >70 overbought / <30 oversold
2. okx-cex-market    okx market indicator bb ETH-USDT --bar 1H
                     → Bollinger Bands: price near upper band = resistance
3. okx-cex-market    okx market indicator kdj ETH-USDT --bar 1H
                     → KDJ J-line confirms overbought / oversold
        ↓ signals confirm overextension → manage position
4. okx-cex-portfolio okx account positions               → check current exposure
5. okx-cex-trade     okx spot place --instId ETH-USDT --side sell --ordType limit --px <px> --sz <sz>
   or               okx spot algo place --instId ETH-USDT --side sell --ordType conditional --sz <sz> --tpTriggerPx <px>
```

---

### BTC macro cycle — long-term position sizing
> User: "Is BTC in a bull market? Is this a good time to accumulate?"

```
1. okx-cex-market    okx market indicator ahr999 BTC-USDT
                     → <0.45: accumulate zone | 0.45–1.2: DCA zone | >1.2: bubble warning
2. okx-cex-market    okx market indicator rainbow BTC-USDT
                     → BTC Rainbow Chart current color band (valuation zone)
3. okx-cex-market    okx market indicator pi-cycle-top BTC-USDT
                     → 111-day MA vs 350-day MA×2: cross = historical cycle top signal
4. okx-cex-market    okx market indicator mayer BTC-USDT
                     → Mayer Multiple (price / 200-day MA): >2.4 historically overvalued
        ↓ cycle context established → size long-term position
5. okx-cex-portfolio okx account balance
6. okx-cex-trade     okx spot place ...  (lump sum) or okx-cex-bot DCA bot for gradual accumulation
```

---

### Discover and price an option
> User: "What's the price of a BTC call option expiring this week?"

```
1. okx-cex-market    okx market open-interest --instType OPTION --instId BTC-USD  → list active option instIds
        ↓ pick target instId from the list (e.g., BTC-USD-250328-95000-C)
2. okx-cex-market    okx market ticker BTC-USD-250328-95000-C → option last price and stats
3. okx-cex-market    okx market orderbook BTC-USD-250328-95000-C → bid/ask spread
```

> **Note**: `okx market instruments --instType OPTION` requires `--uly <underlying>` (e.g., `--uly BTC-USD`). If the underlying is unknown, use `open-interest` first to discover active option instIds.

## Operation Flow

### Step 1: Identify the data needed

- Current price → `okx market ticker`
- All prices for a category → `okx market tickers`
- Order book depth → `okx market orderbook`
- Price history/chart → `okx market candles`
- Funding cost → `okx market funding-rate`
- Contract valuation → `okx market mark-price` or `okx market price-limit`
- Market volume/OI → `okx market open-interest`
- What instruments exist → `okx market instruments`
- Technical indicator (RSI / MACD / EMA / BB / KDJ / SuperTrend / …) → `okx market indicator`
- BTC cycle analysis (AHR999 / Rainbow / Pi-Cycle / Mayer) → `okx market indicator`

### Step 2: Run commands immediately

All market data commands are read-only — no confirmation needed.

- `--instType` values: `SPOT`, `SWAP`, `FUTURES`, `OPTION`
- `--bar` values: `1m`, `3m`, `5m`, `15m`, `30m`, `1H`, `2H`, `4H`, `6H`, `12H`, `1D`, `1W`, `1M`
- `--limit`: number of results (default varies per endpoint, typically 100)
- `--history`: for `funding-rate`, returns historical records instead of current rate

### Step 3: No writes — no verification needed

All commands in this skill are read-only. No post-execution verification required.

## CLI Command Reference

### Ticker — Single Instrument

```bash
okx market ticker <instId> [--json]
```

Returns: `last`, `24h high/low`, `24h volume`, `sodUtc8` (24h change %).

---

### Tickers — All Instruments of a Type

```bash
okx market tickers <instType> [--json]
```

| Param | Required | Values | Description |
|---|---|---|---|
| `instType` | Yes | `SPOT`, `SWAP`, `FUTURES`, `OPTION` | Instrument type |

Returns table: `instId`, `last`, `high24h`, `low24h`, `vol24h`.

---

### Instruments — List Tradeable Instruments

```bash
okx market instruments --instType <type> [--instId <id>] [--json]
```

| Param | Required | Default | Description |
|---|---|---|---|
| `--instType` | Yes | - | `SPOT`, `SWAP`, `FUTURES`, `OPTION` |
| `--instId` | No | - | Filter to a single instrument |

Returns: `instId`, `ctVal`, `lotSz`, `minSz`, `tickSz`, `state`. Displays up to 50 rows.

---

### Order Book

```bash
okx market orderbook <instId> [--sz <n>] [--json]
```

| Param | Required | Default | Description |
|---|---|---|---|
| `instId` | Yes | - | Instrument ID (e.g., `BTC-USDT-SWAP`) |
| `--sz` | No | 5 | Depth levels per side (1–400) |

Displays top 5 asks (ascending) and bids (descending) with price and size.

---

### Candles — OHLCV

```bash
okx market candles <instId> [--bar <bar>] [--limit <n>] [--json]
```

| Param | Required | Default | Description |
|---|---|---|---|
| `instId` | Yes | - | Instrument ID |
| `--bar` | No | `1m` | Time granularity (`1m`, `1H`, `4H`, `1D`, etc.) |
| `--limit` | No | 100 | Number of candles to return |

Returns columns: `time`, `open`, `high`, `low`, `close`, `vol`.

---

### Index Candles

```bash
okx market index-candles <instId> [--bar <bar>] [--limit <n>] [--history] [--json]
```

Same params as `candles`. Use index instrument IDs like `BTC-USD` (not `BTC-USDT`).

---

### Funding Rate

```bash
okx market funding-rate <instId> [--history] [--limit <n>] [--json]
```

| Param | Required | Default | Description |
|---|---|---|---|
| `instId` | Yes | - | SWAP instrument (e.g., `BTC-USDT-SWAP`) |
| `--history` | No | false | Return historical funding rates |
| `--limit` | No | - | Number of historical records |

Current (no `--history`): returns `fundingRate`, `nextFundingRate`, `fundingTime`, `nextFundingTime`.
Historical (`--history`): table with `fundingRate`, `realizedRate`, `fundingTime`.

---

### Recent Trades

```bash
okx market trades <instId> [--limit <n>] [--json]
```

Returns: `tradeId`, `px`, `sz`, `side`, `ts`.

---

### Mark Price

```bash
okx market mark-price --instType <type> [--instId <id>] [--json]
```

Returns: `instId`, `instType`, `markPx`, `ts`. Used for liquidation price calculation and contract valuation.

---

### Index Ticker

```bash
okx market index-ticker [--instId <id>] [--quoteCcy <ccy>] [--json]
```

| Param | Required | Default | Description |
|---|---|---|---|
| `--instId` | Cond. | - | Index ID (e.g., `BTC-USD`) |
| `--quoteCcy` | Cond. | - | Filter by quote currency (e.g., `USD`, `USDT`) |

Returns: `idxPx`, `high24h`, `low24h`.

---

### Price Limit

```bash
okx market price-limit <instId> [--json]
```

Returns: `buyLmt` (max buy price), `sellLmt` (min sell price). Applies to SWAP and FUTURES only.

---

### Open Interest

```bash
okx market open-interest --instType <type> [--instId <id>] [--json]
```

Returns: `oi` (contracts), `oiCcy` (base currency amount), `ts`.

---

### Stock Tokens — List All Stock Token Perpetuals

```bash
okx market stock-tokens [--json]
```

Returns: `instId`, `ctVal`, `lotSz`, `minSz`, `tickSz`, `state` for all active stock token SWAP instruments (`instCategory=3`, e.g., `TSLA-USDT-SWAP`, `NVDA-USDT-SWAP`).

> **Fallback** (if command not yet available): `okx market instruments --instType SWAP --json | jq '[.[] | select(.instCategory == "3")]'` — requires `jq` installed.

---

### Indicator — Technical Analysis

```bash
okx market indicator <indicator> <instId> [--bar <bar>] [--params <n1,n2,...>] [--list] [--limit <n>] [--backtest-time <ms>] [--json]
```

| Param | Required | Default | Description |
|---|---|---|---|
| `indicator` | Yes | - | Indicator name (case-insensitive). See table below. |
| `instId` | Yes | - | Instrument ID (e.g., `BTC-USDT`, `ETH-USDT-SWAP`) |
| `--bar` | No | `1H` | Timeframe: `3m` `5m` `15m` `1H` `4H` `12Hutc` `1Dutc` `3Dutc` `1Wutc` |
| `--params` | No | indicator default | Comma-separated numeric params (e.g., `--params 14` or `--params 5,20`) |
| `--list` | No | false | Return historical list instead of latest value only |
| `--limit` | No | 10 | Number of records when `--list` is set (max 100) |
| `--backtest-time` | No | - | Unix timestamp in ms for backtesting; omit for real-time |

#### Supported Indicators

| Category | Indicator name | Common `--params` | Notes |
|---|---|---|---|
| **Trend** | `ma` | `--params 5,20,60` | Simple moving averages (one or more periods) |
| **Trend** | `ema` | `--params 5,20` | Exponential moving averages |
| **Trend** | `supertrend` | `--params 10,3` | period, multiplier |
| **Trend** | `alphatrend` | - | No params needed |
| **Trend** | `halftrend` | - | No params needed |
| **Trend** | `pmax` | - | No params needed |
| **Momentum** | `rsi` | `--params 14` | Period (default 14) |
| **Momentum** | `macd` | `--params 12,26,9` | fast, slow, signal |
| **Momentum** | `kdj` | `--params 9,3,3` | K, D, J periods |
| **Momentum** | `tdi` | - | Traders Dynamic Index |
| **Momentum** | `qqe` | - | Quantitative Qualitative Estimation |
| **Momentum** | `stoch-rsi` | `--params 14` | Stochastic RSI |
| **Volatility** | `bb` (or `boll`) | `--params 20,2` | period, stddev multiplier — Bollinger Bands |
| **Volatility** | `envelope` | `--params 20,0.1` | period, deviation |
| **Volatility** | `range-filter` | - | No params needed |
| **Volatility** | `waddah` | - | Waddah Attar Explosion |
| **BTC Cycle** | `ahr999` | - | BTC-only. <0.45 accumulate, 0.45–1.2 DCA, >1.2 bubble |
| **BTC Cycle** | `rainbow` | - | BTC-only. Rainbow Chart valuation band |
| **BTC Cycle** | `pi-cycle-top` | - | BTC-only. 111-day MA vs 350-day MA×2 cross = cycle top |
| **BTC Cycle** | `pi-cycle-bottom` | - | BTC-only. Cycle bottom signal |
| **BTC Cycle** | `mayer` | - | BTC-only. Price / 200-day MA. >2.4 historically overvalued |

Returns: `ts` (timestamp) + indicator-specific value fields (e.g., `rsi`, `macd`, `dif`, `dea`, `upper`, `middle`, `lower`, etc.).

---

## MCP Tool Reference

| Tool | Description |
|---|---|
| `market_get_ticker` | Single instrument ticker |
| `market_get_tickers` | All tickers for instType |
| `market_get_instruments` | List instruments |
| `market_get_orderbook` | Order book depth |
| `market_get_candles` | OHLCV candles |
| `market_get_index_candles` | Index OHLCV candles |
| `market_get_funding_rate` | Funding rate (current or history) |
| `market_get_trades` | Recent public trades |
| `market_get_mark_price` | Mark price for contracts |
| `market_get_index_ticker` | Index price ticker |
| `market_get_price_limit` | Price limits for contracts |
| `market_get_open_interest` | Open interest |
| `market_get_indicator` | Technical indicators: MA, EMA, RSI, MACD, BB, KDJ, SuperTrend, AHR999, Rainbow, Pi-Cycle, Mayer, and more |

---

## Input / Output Examples

**"What's the price of BTC?"**
```bash
okx market ticker BTC-USDT
# → instId: BTC-USDT | last: 95000.5 | 24h change %: +1.2% | 24h high: 96000 | 24h low: 93000
```

**"Show me all SWAP tickers"**
```bash
okx market tickers SWAP
# → table of all perpetual contracts with last price, 24h high/low/vol
```

**"What's the BTC/USDT order book look like?"**
```bash
okx market orderbook BTC-USDT
# Asks (price / size):
#          95100.0  2.5
#          95050.0  1.2
# Bids (price / size):
#          95000.0  3.1
#          94950.0  0.8
```

**"Show me BTC 4H candles for the last 30 periods"**
```bash
okx market candles BTC-USDT --bar 4H --limit 30
# → table: time, open, high, low, close, vol
```

**"What's the current funding rate for BTC perp?"**
```bash
okx market funding-rate BTC-USDT-SWAP
# → fundingRate: 0.0001 | nextFundingRate: 0.00012 | fundingTime: ... | nextFundingTime: ...
```

**"Show historical funding rates for ETH perp"**
```bash
okx market funding-rate ETH-USDT-SWAP --history --limit 20
# → table: fundingRate, realizedRate, fundingTime
```

**"What's the open interest on BTC perp?"**
```bash
okx market open-interest --instType SWAP --instId BTC-USDT-SWAP
# → oi: 125000 | oiCcy: 125000 | ts: ...
```

**"List all available SPOT instruments"**
```bash
okx market instruments --instType SPOT
# → table: instId, ctVal, lotSz, minSz, tickSz, state (up to 50 rows)
```

**"What stock tokens can I trade?"**
```bash
okx market stock-tokens
# → table: instId (TSLA-USDT-SWAP, NVDA-USDT-SWAP, AAPL-USDT-SWAP, ...), ctVal, minSz, tickSz, state
```

**"What's the TSLA price?"**
```bash
okx market ticker TSLA-USDT-SWAP
# → instId: TSLA-USDT-SWAP | last: 310.5 | 24h change %: +2.1% | 24h high: 315 | 24h low: 302
```

**"What's the RSI for BTC on the 4H chart?"**
```bash
okx market indicator rsi BTC-USDT --bar 4H --params 14
# BTC-USDT · RSI · 4H
# ────────────────────────────────────────
# ts:  3/20/2026, 08:00:00 AM
# rsi: 63.4
```

**"Show me EMA 5 and EMA 20 for BTC on the 1H to check trend"**
```bash
okx market indicator ema BTC-USDT --bar 1H --params 5,20
# BTC-USDT · EMA · 1H
# ────────────────────────────────────────
# ts:    3/20/2026, 10:00:00 AM
# ema5:  87420.5
# ema20: 86910.2
# (ema5 > ema20 → bullish alignment)
```

**"Is BTC overbought? Check MACD and Bollinger Bands"**
```bash
okx market indicator macd BTC-USDT --bar 4H
# → dif: 312.4 | dea: 280.1 | macd: 64.6  (positive histogram = bullish)

okx market indicator bb BTC-USDT --bar 4H
# → upper: 91200 | middle: 87500 | lower: 83800
# (price near upper band = stretched, watch for reversal)
```

**"Where are we in the BTC cycle? Check AHR999 and Rainbow"**
```bash
okx market indicator ahr999 BTC-USDT
# → ahr999: 0.87  (DCA zone: 0.45–1.2)

okx market indicator rainbow BTC-USDT
# → band: "HODL"  (mid-cycle valuation)

okx market indicator mayer BTC-USDT
# → mayer: 1.31  (below 2.4 threshold — not overvalued)
```

**"Show me the last 20 RSI values for ETH on 1H"**
```bash
okx market indicator rsi ETH-USDT --bar 1H --params 14 --list --limit 20
# → table: ts, rsi  (20 rows, newest first)
```

## Edge Cases

- **instId format**: SPOT uses `BTC-USDT`; SWAP uses `BTC-USDT-SWAP`; FUTURES uses `BTC-USDT-250328`; OPTION uses `BTC-USD-250328-95000-C`; Index uses `BTC-USD`; Stock token SWAP uses `TSLA-USDT-SWAP` (identified by `instCategory=3`)
- **Stock token trading hours**: stock tokens follow underlying exchange hours (US stocks: Mon–Fri ~09:30–16:00 ET). Orders outside trading hours may be queued or rejected — confirm a live last price with `okx market ticker` before trading
- **OPTION instruments — cannot list directly**: `okx market instruments --instType OPTION` requires `--uly BTC-USD` (underlying). If the underlying is unknown, run `okx market open-interest --instType OPTION` first to discover active option instIds from the results, then use those instIds with `okx market ticker <instId>`
- **No data returned**: instrument may be delisted or instId is wrong — verify with `okx market instruments`
- **funding-rate**: only applies to SWAP instruments; returns error for SPOT/FUTURES
- **price-limit**: only applies to SWAP and FUTURES instruments
- **mark-price**: available for SWAP, FUTURES, OPTION; not applicable to SPOT
- **candles --bar**: use uppercase `H`, `D`, `W`, `M` for hour/day/week/month (e.g., `1H` not `1h`)
- **index-ticker**: use `BTC-USD` format (not `BTC-USDT`) for index IDs
- **orderbook --sz**: max depth is 400; default display shows top 5 per side regardless of `--sz`
- **indicator argument order**: `<indicator>` comes before `<instId>` — e.g., `okx market indicator rsi BTC-USDT`, not `okx market indicator BTC-USDT rsi`
- **indicator --bar values**: only `3m`, `5m`, `15m`, `1H`, `4H`, `12Hutc`, `1Dutc`, `3Dutc`, `1Wutc` are supported — not the same as candle bar values; `1D` is written as `1Dutc`
- **indicator --params**: comma-separated, no spaces — e.g., `--params 5,20` not `--params 5 20`
- **BTC-only indicators**: `ahr999`, `rainbow`, `pi-cycle-top`, `pi-cycle-bottom`, `mayer` only work with BTC instruments (e.g., `BTC-USDT`); applying them to ETH or other assets will return no data or an error
- **indicator --list**: without `--list` only the latest single value is returned; add `--list --limit <n>` to retrieve a historical series (max 100)
- **indicator name aliases**: `boll` is accepted as an alias for `bb` (Bollinger Bands); `rainbow` maps to `BTCRAINBOW` internally

## Global Notes

- All market data commands are public — no API key required
- `--json` returns raw OKX API v5 response for programmatic use
- `--profile <name>` has no effect on market commands (no auth needed)
- Rate limit: 20 requests per 2 seconds per IP for market data endpoints
- Candle data is sorted newest-first by default
- `vol24h` in tickers is in base currency (e.g., BTC for BTC-USDT)
