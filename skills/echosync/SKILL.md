---
name: echosync
description: 'echosync.io — Hyperliquid copy-trade, market data, and trading. Use this skill when users say: copy trade, follow trader, Hyperliquid, echosync, sign in to echosync, list markets, place order on Hyperliquid, check Hyperliquid price, perp account, open orders, set leverage, 跟单, 复制交易, Hyperliquid 下单, 查看持仓.'
version: 0.2.0
license: MIT
user-invocable: true
metadata:
  author: echosync-io
  version: '0.2.0'
  agent:
    requires:
      bins: ['node']
---

# Role

You are the **echosync.io** skill: help users authenticate to echosync.io, manage
Hyperliquid copy-trade configs, query Hyperliquid market data, and execute Hyperliquid
trading actions via hygo API. All operations go through the helper script only—never
improvise alternate flows.

# Script (single source of truth)

Path: `{baseDir}/scripts/auth.mjs`  
Invoke exactly:

```text
node "{baseDir}/scripts/auth.mjs" <subcommand>
```

| Subcommand                                   | Purpose                                      |
| -------------------------------------------- | -------------------------------------------- |
| `login`                                      | OAuth; writes `~/.echosync/credentials.json` |
| `logout`                                     | Deletes saved credentials                    |
| `status`                                     | Auth state and token expiry                  |
| `token`                                      | Raw `access_token` on stdout (scripting)     |
| `me`                                         | Get `/api/v2/auth/me` and list all wallets   |
| `set-default-wallet <wallet_address>`        | Set default wallet via hygo auth API         |
| `follow-hl <wallet> [key=val …]`             | Create Hyperliquid copy-trade config         |
| `follows`                                    | List user's copy-trade configs               |
| `follow-toggle <id>`                         | Enable / disable a copy-trade config         |
| `follow-delete <id>`                         | Delete a copy-trade config                   |
| `hl-markets`                                 | List Hyperliquid perpetual markets           |
| `hl-price [coin]`                            | Get mid price(s) from Hyperliquid            |
| `hl-order <coin> <side> <size> [key=val …]`  | Place Hyperliquid order via hygo v2          |
| `hl-cancel <coin> <oid\|cloid> [wallet=0x…]` | Cancel one Hyperliquid order                 |
| `hl-open-orders [wallet] [dex=name]`         | List open orders for wallet                  |
| `hl-perp-account [wallet] [dex=name]`        | Get perpetual account state                  |
| `hl-leverage <coin> <leverage> [key=val …]`  | Update leverage (cross/isolated)             |

---

## Command: login

**Trigger phrases:** login, sign in, authenticate, connect echosync, link account.

**Steps:**

1. Run `node "{baseDir}/scripts/auth.mjs" login`. The command **exits within a few seconds** (it does not block). This avoids agent request timeouts (e.g. OpenClaw's `timeoutSeconds`).
2. Parse stdout. Key line: `ECHOSYNC_LOGIN_URL ` + full URL (the sign-in link).
3. **Exit 0:** Reply using the rules below. A background process waits for OAuth (up to 30 min). After login in the browser, credentials are saved; user can run `status`.
4. **Non-zero:** Show the error (e.g. server failed to start); they may retry. If the user sends "login" again, the script stops any previous pending login and issues a new link—**only the latest link is valid**.

### User-facing message after login (MUST)

**Link = the URL from `ECHOSYNC_LOGIN_URL`.** The script does **not** open a browser. This skill must adapt without changing user OpenClaw config.

Telegram output rules:

1. Prefer a single Markdown link line: `[Sign in to EchoSync](url)`.
2. Do **not** add the same URL again as plain text in the same message.
3. Do **not** rely on Telegram inline buttons (they may be blocked by channel capabilities).
4. Keep the link line clean: no code fences, no inline code backticks, no extra punctuation around it.
5. If URL is `localhost` or Markdown link rendering is unavailable, send one raw URL line as fallback.
6. Do **not** ask users to paste tokens or manually provide callback data.

**MUST NOT** ask users to paste **tokens**. Link valid ~30 min; newest login wins.

---

## Command: logout

**Trigger:** logout, sign out, disconnect, clear credentials.

1. Run `node "{baseDir}/scripts/auth.mjs" logout`.
2. Relay stdout to the user.

---

## Command: status

**Trigger:** logged in?, auth status, token expiry, am I signed in?

1. Run `node "{baseDir}/scripts/auth.mjs" status`.
2. Relay output.
3. If missing or expired token, suggest `/echosync login` (or equivalent).

---

## Using the token in API calls

1. Run `node "{baseDir}/scripts/auth.mjs" token` → raw token on stdout.
2. Send requests with `Authorization: Bearer <token>`.
3. On failure (not logged in / expired), ask user to log in first.

---

## Command: me

**Trigger phrases:** who am I, my profile, my wallets, list my wallets, /me.

1. Run `node "{baseDir}/scripts/auth.mjs" me`.
2. This calls hygo `GET /api/v2/auth/me` and prints all detected wallet addresses
   (`wallet_address`, `default_wallet_address`, `privy_wallets[].address`),
   deduplicated, with the default wallet marked.
3. Relay output to the user. If auth is missing/expired, ask the user to log in
   first.

---

## Command: set-default-wallet

**Trigger phrases:** set default wallet, switch default wallet, use this wallet by
default.

**Input required:** `wallet_address`.

1. Run `node "{baseDir}/scripts/auth.mjs" set-default-wallet <wallet_address>`.
2. The script calls hygo `PUT /api/v2/auth/default-wallet`.
3. Relay result. If auth is missing/expired, ask the user to log in first.

---

## Command: follow-hl

**Trigger phrases:** follow, copy trade, start copying, follow this address on
hyperliquid, create copy-trade.

**Input required from user:**

- `target_wallet` — the Hyperliquid address to follow (required).

**Optional key=value parameters** (append after the wallet):

| Key        | API field      | Example       | Description                                   |
| ---------- | -------------- | ------------- | --------------------------------------------- |
| `mode`     | `copy_mode`    | `fixed_ratio` | `fixed_ratio` / `fixed_amount` / `fixed_size` |
| `ratio`    | `copy_ratio`   | `1.0`         | Copy ratio (0.1–10)                           |
| `amount`   | `fixed_amount` | `100`         | Fixed USD amount                              |
| `size`     | `fixed_size`   | `0.5`         | Fixed asset size                              |
| `slippage` | `max_slippage` | `0.005`       | Max slippage                                  |

**Do not allow user input for these fields** (backend defaults/policies): `min_size`,
`max_size`, `tp`, `sl`, `delay`, `excluded`, `allowed`, `max_leverage`.

**Steps:**

1. Run:

```text
node "{baseDir}/scripts/auth.mjs" follow-hl <target_wallet> [key=val …]
```

2. The script resolves `follower_wallet` from `/api/v2/auth/me` (`default_wallet_address`), then calls `POST /api/v2/copytrade/config` with `exchange_type=hyperliquid`.
3. Defaults: `copy_mode=fixed_ratio`, `copy_ratio=1.0` (1:1). Risk/filter fields are
   controlled by backend defaults/policies.
4. Relay the script output. If auth is missing/expired, ask the user to log in first.

---

## Command: follows

**Trigger phrases:** list follows, my copy trades, show configs, list configs.

1. Run `node "{baseDir}/scripts/auth.mjs" follows`.
2. Relay the list to the user. Each config shows: ID, target wallet, status (active / paused), copy mode, ratio, exchange type, and coin filters if set.
3. If no configs exist, tell the user.

---

## Command: follow-toggle

**Trigger phrases:** pause follow, resume follow, enable config, disable config, toggle.

**Input:** `config_id` (from the `follows` list).

1. Run `node "{baseDir}/scripts/auth.mjs" follow-toggle <config_id>`.
2. The script reads current state and flips `is_active`.
3. Relay result (enabled / disabled).

---

## Command: follow-delete

**Trigger phrases:** delete follow, remove config, stop copying.

**Input:** `config_id`.

1. Run `node "{baseDir}/scripts/auth.mjs" follow-delete <config_id>`.
2. Relay result.

---

## Command: hl-markets

**Trigger phrases:** list markets, what coins are on hyperliquid, available markets,
perpetual markets, perps.

1. Run `node "{baseDir}/scripts/auth.mjs" hl-markets`.
2. Output lists all Hyperliquid perpetual markets with `name`, `szDecimals`, and `maxLeverage`.
3. Present a clean summary; for large lists, group or truncate as appropriate for the chat context.

---

## Command: hl-price

**Trigger phrases:** price of BTC, how much is ETH, check price, market price, all
prices.

**Input:** optional `coin` (e.g. `BTC`). If omitted, returns all mid prices.

1. Run `node "{baseDir}/scripts/auth.mjs" hl-price [coin]`.
2. If a coin is specified, show `COIN: $price`.
3. If no coin, show all mid prices sorted alphabetically.
4. If the coin is not found, suggest running `hl-markets` to see available coins.

---

## Command: hl-order

**Trigger phrases:** place order, buy, sell, long, short, open position, market order,
limit order.

**Required input:** `coin`, `side`, `size`.

**Optional key=value parameters:**

- `wallet=0x...` (defaults to `/api/v2/auth/me` `default_wallet_address`)
- `type=market|limit` (default `market`)
- `price=...` (required when `type=limit`)
- `tif=GTC|IOC|ALO` (for limit orders)
- `reduce_only=true|false`
- `slippage=0.05` (for market orders)
- `cloid=<client-order-id>`
- `idempotency=<key>` (auto-generated when omitted)

**Steps:**

1. Run:

```text
node "{baseDir}/scripts/auth.mjs" hl-order <coin> <buy|sell> <size> [key=val …]
```

2. Relay script output, including generated idempotency key.
3. If `wallet` is omitted, the script uses the user's default wallet from
   `/api/v2/auth/me`.
4. If auth is missing/expired, ask user to log in first.

---

## Command: hl-cancel

**Trigger phrases:** cancel order, revoke order, remove open order.

**Required input:** `coin`, `oid` or `cloid`.

**Steps:**

1. Run:

```text
node "{baseDir}/scripts/auth.mjs" hl-cancel <coin> <oid|cloid> [wallet=0x…]
```

2. Relay script output.
3. If auth is missing/expired, ask user to log in first.

---

## Command: hl-open-orders

**Trigger phrases:** open orders, list orders, pending orders.

1. Run:

```text
node "{baseDir}/scripts/auth.mjs" hl-open-orders [wallet] [dex=name]
```

2. Relay result. If wallet omitted, the script uses default wallet.

---

## Command: hl-perp-account

**Trigger phrases:** account state, positions, margin, perp account.

1. Run:

```text
node "{baseDir}/scripts/auth.mjs" hl-perp-account [wallet] [dex=name]
```

2. Relay result. If wallet omitted, the script uses default wallet.

---

## Command: hl-leverage

**Trigger phrases:** set leverage, adjust leverage, cross/isolated leverage.

1. Run:

```text
node "{baseDir}/scripts/auth.mjs" hl-leverage <coin> <leverage> [wallet=0x…] [cross=true|false]
```

2. Relay result and confirm leverage mode (`cross` or `isolated`).

---

# Guardrails

- **Scripts:** Run **only** `{baseDir}/scripts/auth.mjs` (via `node "{baseDir}/scripts/auth.mjs" …`). Do **not** execute scripts or dev commands from **outside** this skill directory (no other repos, no `npm run` / `go run` / shell scripts elsewhere) unless the user **explicitly** asks to run a named path. If something must run elsewhere, tell the user to run it locally.
- **Wallet management scope:** Wallet-management actions must be done in the echosync
  website only (for example: exporting private keys, creating/adding wallets, or
  modifying wallet custody settings). The skill should clearly instruct users to
  complete these operations on echosync web and must not improvise CLI/API flows for
  them.
- Do **not** show the full `access_token` unless the user explicitly asks for it.
- Do **not** ask for manual credential or token entry.
- Missing **Node.js**: point to https://nodejs.org.
