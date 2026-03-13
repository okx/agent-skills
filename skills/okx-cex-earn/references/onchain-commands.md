# On-chain Earn Command Reference

## earn onchain offers

```bash
okx --profile live earn onchain offers
okx --profile live earn onchain offers --ccy ETH
okx --profile live earn onchain offers --protocolType staking
```

| Parameter | Required | Description |
|---|---|---|
| `--ccy` | No | Filter by currency |
| `--protocolType` | No | `staking` or `defi` |
| `--productId` | No | Specific product |

Key output fields: `productId` · `ccy` · `protocol` · `protocolType` · `apy` · `term` · `minAmt` · `redeemPeriod` · `earningData`

When multiple products exist for the same currency, compare and highlight: APY, protocol, reward structure (`earningData`), redemption period.

---

## earn onchain purchase

Subscribe to an on-chain earn product. Moves real funds to on-chain protocol.

```bash
okx --profile live earn onchain purchase --productId 4013 --ccy ETH --amt 1
okx --profile live earn onchain purchase --productId 4013 --ccy ETH --amt 1 --term 30
```

| Parameter | Required | Description |
|---|---|---|
| `--productId` | Yes | Product ID from `offers` |
| `--ccy` | Yes | Currency to invest |
| `--amt` | Yes | Amount |
| `--term` | Conditional | Days; required for fixed-term products |

**Pre-execution checklist:**
1. Show summary: protocol, currency, amount, lock period, total APY (net of fees), reward breakdown (`earningData`)
2. Show risk disclaimer (mandatory):
   > ⚠️ OKX connects to third-party DeFi protocols and only provides information display and earnings distribution services. OKX is not liable for asset losses caused by smart contract vulnerabilities, hacking, or DeFi project failures.
3. Wait for explicit user confirmation

---

## earn onchain redeem

```bash
okx --profile live earn onchain redeem --ordId 12345 --protocolType staking
okx --profile live earn onchain redeem --ordId 12345 --protocolType staking --allowEarlyRedeem
```

| Parameter | Required | Description |
|---|---|---|
| `--ordId` | Yes | Order ID |
| `--protocolType` | Yes | `staking` or `defi` |
| `--allowEarlyRedeem` | No | Allow early redemption (may incur penalty) |

Show `estSettlementTime` as estimated arrival time. If early redemption, explicitly state any penalty. Wait for confirmation.

> `cancelRedemptionDeadline` is returned by the API but cancelling a redemption is not supported — do not show this field.

---

## earn onchain cancel

Cancel a pending on-chain order (not yet on-chain).

```bash
okx --profile live earn onchain cancel --ordId 12345 --protocolType defi
```

Only for `state: 8` (pending). Orders already on-chain cannot be cancelled — use redeem instead.

---

## earn onchain orders

```bash
okx --profile live earn onchain orders --json
okx --profile live earn onchain orders --ccy ETH --protocolType staking --json
```

Always use `--json` and render results as a Markdown table. Show reward breakdown from `earningData`. Translate state codes using the table below.

### Order States

| State | Meaning |
|---|---|
| `8` | Pending (not yet on-chain) — can be cancelled |
| `9` | On-chain (processing) — cannot be cancelled, use redeem |
| `1` | Earning (active) |
| `2` | Redeeming |
| `3` | Cancelling (cancel submitted, not yet complete) |

---

## earn onchain history

```bash
okx --profile live earn onchain history --json
okx --profile live earn onchain history --ccy ETH --json
okx --profile live earn onchain history --ccy ETH --limit 20 --json
```

| Parameter | Required | Description |
|---|---|---|
| `--ccy` | No | Filter by currency |
| `--limit` | No | Max results (default 100) |

Output fields: `ordId` · `productId` · `ccy` · `amt` · `apy` · `protocol` · `protocolType` · `state` · `earningData` · `redeemAmt` · `redeemTs`
