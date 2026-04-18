---
name: okx-cex-auth
description: "Use this skill when any OKX CLI command fails with a missing-credentials or auth-required error ('No credentials found', 'Run `okx auth login` first', 'Session expired', 'not authenticated', 'requires_auth', '401 Unauthorized', 'StorageNotFoundError', '会话过期', '未认证'), OR when the user explicitly asks to 'login', 'log in', 'sign in', 'authenticate', 'connect OKX account', '登录', '授权', '认证'. Also use before first-time use of okx-cex-trade, okx-cex-portfolio, okx-cex-earn, or okx-cex-bot when credentials may be missing. Also use for managing the okx-auth binary ('install auth', 'remove auth', 'Failed to spawn okx-auth', '安装认证', '卸载认证'). Do NOT use for market data queries (use okx-cex-market)."
license: MIT
metadata:
  author: okx
  version: "1.2.0"
  homepage: "https://www.okx.com"
  agent:
    requires:
      bins: ["okx"]
    install:
      - id: npm
        kind: node
        package: "@okx_ai/okx-trade-cli@1.3.1-beta.14"
        bins: ["okx"]
        label: "Install okx CLI (npm)"
---

# OKX CEX Authentication

Two credential paths: **API key (HMAC)** and **OAuth (device flow)**. The CLI's `applyAuth` logic is:

```
1. apiKey + secretKey + passphrase all present → HMAC signing. NO fallback to OAuth.
2. Otherwise → OAuth Bearer token via okx-auth binary.
3. Neither → throw "No credentials found".
```

This means: **if API key is configured, it is always used**. You must never trigger OAuth when API key exists.

---

## AGENT RULES (non-negotiable)

1. **NEVER** run `okx auth login` without `--manual`. The non-`--manual` form blocks on stdin and will hang.
2. **NEVER** run `okx config init`. It is interactive and blocks on stdin.
3. **NEVER** ask the user "live or demo" before login. The CLI handles mode via config/flags; the agent should not pre-ask.
4. **NEVER** fall back to OAuth when API key is configured. If API key is present and fails, guide the user to fix the key — never propose OAuth instead.
5. **NEVER** start a login flow without first checking `okx config show --json` for existing credentials.

---

## Decision tree (run this verbatim)

### Step 1 — Detect credentials

Run:

```bash
okx config show --json
```

Parse the output. Locate `profiles[<default_profile>]`. Look at `api_key`:

- If `api_key` is `"(not set)"` or absent → **No-API-key path** (§A below)
- If `api_key` is a masked value (e.g. `ok-****1234`) → **Has-API-key path** (§B below)

### §A — No API key → OAuth device flow

**MANDATORY.** When `api_key` is `(not set)`, the ONLY correct next action is to run OAuth. Do not offer alternatives.

**HARD PROHIBITIONS in §A:**
- DO NOT suggest the user create `~/.okx/config.toml` manually.
- DO NOT suggest API key setup as an option ("Option 1 / Option 2" framing is forbidden).
- DO NOT ask the user to choose between API key and OAuth. They have no API key; there is no choice.
- DO NOT explain both paths. Only describe what you are doing now (OAuth).
- DO NOT proactively mention API keys at all in this path.

If the user later explicitly says "I want to use API key instead", then stop §A and let them configure it themselves — but you must NEVER initiate that suggestion.

#### §A.1 — Start login; CLI decides whether to ask for site

First attempt (let CLI inherit persisted site if any):

```bash
okx auth login --manual
```

Inspect the output:

**Case A — First-time login.** stderr contains:

```
No site configured. Let's set one up for OAuth login.
Error: Site selection: IO error: not a terminal
```

CLI has no persisted site. Output this message EXACTLY (do not rephrase, do not translate, do not add extra text):

```
您需要选择 OKX 站点：

1. Global (www.okx.com)
2. EEA (my.okx.com)
3. US (app.okx.com)

请告诉我您要选择哪个站点（1、2 或 3）。
```

Wait for the user's reply. Map to a `--site` value (do NOT pick a default on empty reply — ask again instead):

| User reply     | `--site` value |
| -------------- | -------------- |
| `1` / `global` | `global`       |
| `2` / `eea`    | `eea`          |
| `3` / `us`     | `us`           |
| empty / other  | ask again      |

Re-run with the chosen site:

```bash
okx auth login --manual --site <selected>
```

CLI persists the choice into `~/.okx/config.toml`. Subsequent logins inherit silently.

**Case B — Returning login.** stdout contains JSON `{"verificationUri":..., "userCode":...}`. CLI inherited the last site from config.toml. Proceed to §A.3 — do NOT re-ask for site.

#### §A.3 — Surface the URL and code

Parse the JSON output. It contains `verificationUri` and `userCode`. Surface them to the user exactly as (do NOT rephrase):

```
请打开以下链接，输入验证码完成授权：
授权地址：<verificationUri>
验证码：<userCode>
授权完成后告诉我，我继续后续操作。
```

Do not ask extra questions. Do not re-ask for site (already done in §A.1). Do not mention API keys.

#### §A.4 — Poll for completion

Poll every 10 seconds (up to ~10 minutes):

```bash
okx auth status --json
```

Read the `status` field:

| `status`        | Action                                                         |
| --------------- | -------------------------------------------------------------- |
| `pending`       | Keep polling                                                   |
| `logged_in`     | Stop polling. Resume the user's original request.             |
| `not_logged_in` | Device code expired. Ask the user if they want to retry (§A.1) |

**Do not run any other `okx` command while polling.**

#### §A.5 — Switch site (user explicitly requests)

Trigger ONLY when the user explicitly asks to change site (e.g. "换站点", "switch site", "换到 EEA"). Do NOT trigger automatically based on any other signal.

1. Logout (clears tokens; `config.toml` site preserved, will be overwritten next):

```bash
okx auth logout
```

2. Ask the user for the new site — output the EXACT message from §A.1 Case A.

3. Re-login with explicit `--site` to overwrite the persisted choice:

```bash
okx auth login --manual --site <new>
```

CLI updates `~/.okx/config.toml` automatically. No file cleanup required.

### §B — API key configured → fix the key, never switch to OAuth

1. Inspect the original error.

   | OKX code | Meaning                      | Tell the user                                             |
   | -------- | ---------------------------- | --------------------------------------------------------- |
   | `50100`  | Key lacks permission         | Update the API key's permissions in the OKX web console and try again. |
   | `50110`  | Key expired                  | The API key has expired. Generate a new key and update `~/.okx/config.toml`. |
   | other    | Config/signature mismatch    | Check `api_key`, `secret_key`, `passphrase` in `~/.okx/config.toml` for typos; confirm the profile is for the correct site (global/eea/us). |

2. Show the user how to update the key (path + which field). Then stop. Do not start OAuth.

---

## Status check (standalone)

```bash
okx auth status --json
```

Output shape:

```json
{
  "profile": "oauth",
  "site": "global",
  "status": "logged_in",
  "expiresAt": "2026-04-17T20:30:00Z",
  "ttl": 3600,
  "scopes": ["live:read", "live:trade"]
}
```

| `status`        | Meaning                    |
| --------------- | -------------------------- |
| `logged_in`     | Valid session              |
| `pending`       | Login in progress          |
| `not_logged_in` | No active session          |

---

## Logout

```bash
okx auth logout
```

DCR client registration is retained. The next `--manual` login will be faster.

---

## Binary management (okx-auth)

The `okx auth` commands depend on the `okx-auth` binary (installed during `npm install`).

| Task               | Command                            |
| ------------------ | ---------------------------------- |
| Install / update   | `okx auth install`                 |
| Check              | `okx auth install-status`          |
| Remove             | `okx auth remove --force`          |

If `Failed to spawn okx-auth` appears: run `okx auth install`, verify with `install-status`, retry original command.

> Use the CLI commands. **Do NOT** manually check platform, CDN, or binary paths.

---

## Error reference

| Error                                                 | Cause                               | Action                                                     |
| ----------------------------------------------------- | ----------------------------------- | ---------------------------------------------------------- |
| `No credentials found. Run okx auth login ...`        | No api_key and no OAuth session     | §A                                                         |
| `Session expired — run okx auth login again`          | OAuth refresh token expired         | §A                                                         |
| OKX code `50100`                                      | API key permission missing          | §B, row 1                                                  |
| OKX code `50110`                                      | API key expired                     | §B, row 2                                                  |
| OKX code `51155` / `51734`                            | Region / site mismatch              | Re-login with `--site` matching account region (§A)        |
| `Authorization timed out`                             | User didn't authorize in time       | §A.1, retry                                                |
| `Failed to spawn okx-auth`                            | Binary missing                      | `okx auth install`, then retry                             |

---

## Skill routing (after auth established)

| Then the user wants...                       | Next skill                          |
| -------------------------------------------- | ----------------------------------- |
| Place / cancel / amend orders                | `okx-cex-trade`                     |
| Balance, positions, P&L                      | `okx-cex-portfolio`                 |
| Simple/On-chain Earn, DCD, AutoEarn          | `okx-cex-earn`                      |
| Grid / DCA bots                              | `okx-cex-bot`                       |
| Public market data (prices, candles)         | `okx-cex-market` (no auth required) |
