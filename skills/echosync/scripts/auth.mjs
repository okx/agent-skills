#!/usr/bin/env node
/**
 * echosync.io OAuth CLI helper
 *
 * Usage:
 *   node auth.mjs login    — output login URL; complete OAuth, save token
 *   node auth.mjs logout   — remove saved credentials
 *   node auth.mjs status   — show current auth state
 *   node auth.mjs token    — print access_token (for piping)
 */

import http from 'node:http';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const SCRIPT_DIR = dirname(fileURLToPath(import.meta.url));
const ASSETS_DIR = join(SCRIPT_DIR, '..', 'assets');
const CALLBACK_HTML_PATH = join(ASSETS_DIR, 'callback.html');
const CALLBACK_OK_HTML_PATH = join(ASSETS_DIR, 'callback-ok.html');
const CALLBACK_ERR_HTML_PATH = join(ASSETS_DIR, 'callback-error.html');

// ── .env loading (best-effort, no dependencies) ──────────────────────────────

function loadDotenv() {
  const envPath = join(SCRIPT_DIR, '.env');
  if (!existsSync(envPath)) return {};
  const vars = {};
  for (const line of readFileSync(envPath, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq < 1) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    vars[key] = val;
  }
  return vars;
}

const dotenv = loadDotenv();

// ── Config ────────────────────────────────────────────────────────────────────

const OAUTH_WEB_URL =
  process.env.ECHOSYNC_OAUTH_URL ??
  dotenv.ECHOSYNC_OAUTH_URL ??
  'https://oa.echosync.io';
const API_V2_BASE_URL =
  process.env.ECHOSYNC_API_V2_URL ??
  dotenv.ECHOSYNC_API_V2_URL ??
  'https://go.echosync.io';
const CREDS_DIR = join(homedir(), '.echosync');
const CREDS_FILE = join(CREDS_DIR, 'credentials.json');
const LOGIN_LOCK = join(CREDS_DIR, 'login.lock');
const LOGIN_PORT_FILE = join(CREDS_DIR, 'login.port');
const TIMEOUT_MS = 30 * 60 * 1000; // 30 min
const PORT_POLL_MS = 50;
const PORT_POLL_ATTEMPTS = 100; // 5s max wait for child to listen
const ETH_ADDR_REGEX = /^0x[a-fA-F0-9]{40}$/;
const HL_INFO_URL = 'https://api.hyperliquid.xyz/info';
const { cmd, args, verbose: VERBOSE } = parseCliArgs(process.argv.slice(2));

// ── Helpers ───────────────────────────────────────────────────────────────────

function parseCliArgs(argv) {
  const filtered = [];
  let verbose = false;
  for (const arg of argv) {
    if (arg === '-v') {
      verbose = true;
      continue;
    }
    filtered.push(arg);
  }
  const [cmd, ...args] = filtered;
  return { cmd, args, verbose };
}

function parseRequestBody(body) {
  if (typeof body !== 'string') return body ?? null;
  const trimmed = body.trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch {
    return trimmed;
  }
}

function parseQueryParams(url) {
  try {
    const query = {};
    const parsed = new URL(url);
    for (const [k, v] of parsed.searchParams.entries()) {
      if (!(k in query)) {
        query[k] = v;
        continue;
      }
      if (Array.isArray(query[k])) {
        query[k].push(v);
      } else {
        query[k] = [query[k], v];
      }
    }
    return query;
  } catch {
    return {};
  }
}

function printVerboseRequest(url, options = {}) {
  if (!VERBOSE) return;
  const method = String(options.method ?? 'GET').toUpperCase();
  const query = parseQueryParams(url);
  const body = parseRequestBody(options.body);
  console.error(`[verbose] request ${method} ${url}`);
  console.error(
    `[verbose] params ${JSON.stringify(
      {
        query,
        body,
      },
      null,
      2
    )}`
  );
}

function acquireLoginLock() {
  mkdirSync(CREDS_DIR, { recursive: true });
  if (existsSync(LOGIN_LOCK)) {
    try {
      const prev = JSON.parse(readFileSync(LOGIN_LOCK, 'utf8'));
      const pid = typeof prev.pid === 'number' ? prev.pid : 0;
      if (pid > 0 && pid !== process.pid) {
        try {
          process.kill(pid, 'SIGTERM');
        } catch (e) {
          if (e.code !== 'ESRCH') throw e;
        }
      }
    } catch {
      /* stale lock */
    }
    try {
      rmSync(LOGIN_LOCK, { force: true });
    } catch {
      /* ignore */
    }
  }
  writeFileSync(LOGIN_LOCK, JSON.stringify({ pid: process.pid, started: Date.now() }), {
    mode: 0o600,
  });
  const release = () => {
    try {
      if (!existsSync(LOGIN_LOCK)) return;
      const cur = JSON.parse(readFileSync(LOGIN_LOCK, 'utf8'));
      if (cur.pid === process.pid) rmSync(LOGIN_LOCK, { force: true });
    } catch {
      /* ignore */
    }
  };
  process.once('SIGTERM', () => {
    release();
    process.exit(143);
  });
  process.once('SIGINT', () => {
    release();
    process.exit(130);
  });
  return release;
}

function saveCredentials(data) {
  mkdirSync(CREDS_DIR, { recursive: true });
  writeFileSync(CREDS_FILE, JSON.stringify(data, null, 2), { mode: 0o600 });
}

function loadCredentials() {
  if (!existsSync(CREDS_FILE)) return null;
  try {
    return JSON.parse(readFileSync(CREDS_FILE, 'utf8'));
  } catch {
    return null;
  }
}

// OAuth may redirect with tokens in the hash (#access=...), which never hits the
// server. callback.html only promotes hash → query via location.replace; the
// second GET is handled here (save creds + static result pages).
function escapeHtmlText(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

let callbackRelayHtmlCache;
let callbackOkHtmlCache;
let callbackErrTemplate;

function readCallbackRelayHtml() {
  if (callbackRelayHtmlCache === undefined) {
    callbackRelayHtmlCache = readFileSync(CALLBACK_HTML_PATH, 'utf8');
  }
  return callbackRelayHtmlCache;
}

function readCallbackOkHtml() {
  if (callbackOkHtmlCache === undefined) {
    callbackOkHtmlCache = readFileSync(CALLBACK_OK_HTML_PATH, 'utf8');
  }
  return callbackOkHtmlCache;
}

function callbackErrHtml(detail) {
  if (callbackErrTemplate === undefined) {
    callbackErrTemplate = readFileSync(CALLBACK_ERR_HTML_PATH, 'utf8');
  }
  return callbackErrTemplate.replace(/__DETAIL__/g, escapeHtmlText(detail));
}

// ── Commands ──────────────────────────────────────────────────────────────────

/** Runs in a detached child: holds callback server until OAuth or 30min timeout. */
function cmdLoginServer() {
  const releaseLock = acquireLoginLock();
  const cleanup = () => {
    try {
      rmSync(LOGIN_PORT_FILE, { force: true });
    } catch {
      /* ignore */
    }
    releaseLock();
  };
  process.removeAllListeners('SIGTERM');
  process.removeAllListeners('SIGINT');
  process.once('SIGTERM', () => {
    cleanup();
    process.exit(143);
  });
  process.once('SIGINT', () => {
    cleanup();
    process.exit(130);
  });

  const server = http.createServer();
  server.listen(0, '127.0.0.1', () => {
    const { port } = server.address();
    writeFileSync(LOGIN_PORT_FILE, JSON.stringify({ port }), { mode: 0o600 });

    const timer = setTimeout(() => {
      server.close();
      cleanup();
      process.exit(1);
    }, TIMEOUT_MS);

    server.on('request', (req, res) => {
      const url = new URL(req.url, `http://localhost:${port}`);

      if (url.pathname === '/callback' && req.method === 'GET') {
        res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
        const oauthError = url.searchParams.get('error');
        const oauthDesc = url.searchParams.get('error_description');
        const access_token = url.searchParams.get('access_token');
        const expires_in_raw = url.searchParams.get('expires_in');
        const hasQuery = [...url.searchParams.keys()].length > 0;

        if (oauthError) {
          const detail = oauthDesc?.trim() || oauthError;
          res.end(callbackErrHtml(detail));
          return;
        }
        if (access_token) {
          const expires_in = Number(expires_in_raw ?? '0') || 0;
          const expires_at =
            expires_in > 0 ? Math.floor(Date.now() / 1000) + expires_in : null;
          saveCredentials({
            access_token,
            expires_at,
            saved_at: Math.floor(Date.now() / 1000),
          });
          res.end(readCallbackOkHtml());
          clearTimeout(timer);
          server.close(() => {
            cleanup();
            process.exit(0);
          });
          return;
        }
        if (hasQuery) {
          res.end(callbackErrHtml('Missing access_token.'));
          return;
        }
        res.end(readCallbackRelayHtml());
        return;
      }

      res.writeHead(404);
      res.end('not found');
    });

    server.on('error', () => {
      clearTimeout(timer);
      cleanup();
      process.exit(1);
    });
  });
}

/** Main process: spawn detached server child, print URL, exit immediately. */
async function cmdLogin() {
  mkdirSync(CREDS_DIR, { recursive: true });
  try {
    rmSync(LOGIN_PORT_FILE, { force: true });
  } catch {
    /* ignore */
  }

  const scriptPath = fileURLToPath(import.meta.url);
  const child = spawn(process.execPath, [scriptPath, '_login-server'], {
    detached: true,
    stdio: 'ignore',
    env: process.env,
    cwd: process.cwd(),
  });
  child.unref();

  for (let i = 0; i < PORT_POLL_ATTEMPTS; i++) {
    await new Promise((r) => setTimeout(r, PORT_POLL_MS));
    if (!existsSync(LOGIN_PORT_FILE)) continue;
    try {
      const { port } = JSON.parse(readFileSync(LOGIN_PORT_FILE, 'utf8'));
      if (typeof port === 'number' && port > 0) {
        const loginUrl = `${OAUTH_WEB_URL}?redirect_uri=${encodeURIComponent(`http://localhost:${port}/callback`)}`;
        console.log(`ECHOSYNC_LOGIN_URL ${loginUrl}`);
        console.log('\nValid for 30 min.\n');
        return;
      }
    } catch {
      /* retry */
    }
  }

  throw new Error('Login server failed to start. Try again.');
}

function cmdLogout() {
  if (existsSync(CREDS_FILE)) {
    rmSync(CREDS_FILE);
    console.log('✓ Credentials removed.');
  } else {
    console.log('Not logged in.');
  }
}

function cmdStatus() {
  const creds = loadCredentials();
  if (!creds) {
    console.log('Not logged in. Run: openclaw login');
    process.exit(1);
  }
  const now = Math.floor(Date.now() / 1000);
  const expired = creds.expires_at && creds.expires_at < now;
  if (expired) {
    console.log('⚠ Token expired. Run: openclaw login');
    process.exit(1);
  }
  const expiresIn = creds.expires_at ? creds.expires_at - now : null;
  console.log('✓ Logged in');
  if (expiresIn !== null) {
    const h = Math.floor(expiresIn / 3600);
    const m = Math.floor((expiresIn % 3600) / 60);
    console.log(`  Expires in: ${h}h ${m}m`);
  }
  console.log(`  Token: ${creds.access_token.slice(0, 12)}…`);
}

function cmdToken() {
  const creds = loadCredentials();
  if (!creds) {
    console.error('Not logged in.');
    process.exit(1);
  }
  const now = Math.floor(Date.now() / 1000);
  if (creds.expires_at && creds.expires_at < now) {
    console.error('Token expired. Run: openclaw login');
    process.exit(1);
  }
  process.stdout.write(creds.access_token);
}

function requireAccessToken() {
  const creds = loadCredentials();
  if (!creds || !creds.access_token) {
    throw new Error('Not logged in. Run: node auth.mjs login');
  }
  const now = Math.floor(Date.now() / 1000);
  if (creds.expires_at && creds.expires_at < now) {
    throw new Error('Token expired. Run: node auth.mjs login');
  }
  return creds.access_token;
}

function parseKeyValueArgs(rawArgs) {
  const out = {};
  for (const arg of rawArgs) {
    if (typeof arg !== 'string') continue;
    const eq = arg.indexOf('=');
    if (eq < 1) continue;
    const key = arg.slice(0, eq).trim();
    const val = arg.slice(eq + 1).trim();
    if (!key) continue;
    out[key] = val;
  }
  return out;
}

function parseBool(val, fallback = false) {
  if (val === undefined || val === null || val === '') return fallback;
  const s = String(val).toLowerCase();
  if (['1', 'true', 'yes', 'y', 'on'].includes(s)) return true;
  if (['0', 'false', 'no', 'n', 'off'].includes(s)) return false;
  return fallback;
}

function extractEthAddresses(userInfo) {
  const addresses = new Set();
  const pushAddr = (value) => {
    if (typeof value !== 'string') return;
    const normalized = value.trim().toLowerCase();
    if (!ETH_ADDR_REGEX.test(normalized)) return;
    addresses.add(normalized);
  };

  pushAddr(userInfo?.wallet_address);
  pushAddr(userInfo?.default_wallet_address);
  if (Array.isArray(userInfo?.privy_wallets)) {
    for (const wallet of userInfo.privy_wallets) {
      if (wallet && typeof wallet === 'object') {
        pushAddr(wallet.address);
      }
    }
  }
  return [...addresses];
}

function normalizeSide(side) {
  const s = String(side ?? '').toUpperCase();
  if (s === 'BUY' || s === 'LONG') return 'BUY';
  if (s === 'SELL' || s === 'SHORT') return 'SELL';
  throw new Error('side must be buy/sell (or long/short)');
}

async function requestApi(path, token, options = {}) {
  const baseUrl = resolveApiBaseForPath(path);
  const url = `${baseUrl}${path}`;
  printVerboseRequest(url, options);
  const res = await fetch(url, {
    ...options,
    headers: {
      authorization: `Bearer ${token}`,
      ...(options.headers ?? {}),
    },
  });

  const rawText = await res.text();
  let body = null;
  try {
    body = rawText ? JSON.parse(rawText) : null;
  } catch {
    body = null;
  }
  if (!res.ok) {
    const jsonError =
      body && typeof body.error === 'string' && body.error ? body.error : null;
    const bodyMsg =
      typeof rawText === 'string' && rawText.trim() ? rawText.trim() : null;
    const msg = jsonError ?? bodyMsg ?? `HTTP ${res.status}`;
    throw new Error(msg);
  }
  return body;
}

function resolveApiBaseForPath(path) {
  if (typeof path !== 'string') return API_V2_BASE_URL;
  if (path.startsWith('/api/v2/')) return API_V2_BASE_URL;
  return API_V2_BASE_URL;
}

async function resolveTradingWallet(token, walletOverride) {
  if (walletOverride) {
    if (!ETH_ADDR_REGEX.test(walletOverride)) {
      throw new Error(`Invalid wallet address: ${walletOverride}`);
    }
    return walletOverride.toLowerCase();
  }
  const me = await requestApi('/api/v2/auth/me', token, { method: 'GET' });
  const userInfo = me && typeof me.data === 'object' && me.data ? me.data : {};
  return resolveFollowerWallet(userInfo);
}

async function cmdMe() {
  const token = requireAccessToken();
  const me = await requestApi('/api/v2/auth/me', token, { method: 'GET' });
  const userInfo = me && typeof me.data === 'object' && me.data ? me.data : {};
  const walletAddresses = extractEthAddresses(userInfo);
  const defaultWallet =
    typeof userInfo.default_wallet_address === 'string'
      ? userInfo.default_wallet_address.toLowerCase()
      : null;

  console.log('Current user profile (/api/v2/auth/me):');
  if (walletAddresses.length === 0) {
    console.log('  Wallets: none');
  } else {
    console.log(`  Wallets (${walletAddresses.length}):`);
    for (const addr of walletAddresses) {
      const suffix = defaultWallet && addr === defaultWallet ? ' (default)' : '';
      console.log(`    - ${addr}${suffix}`);
    }
  }
  console.log('\nRaw:\n' + JSON.stringify(userInfo, null, 2));
}

async function cmdSetDefaultWallet(walletAddress) {
  if (!walletAddress || !ETH_ADDR_REGEX.test(walletAddress)) {
    throw new Error('Usage: node auth.mjs set-default-wallet <wallet_address>');
  }
  const token = requireAccessToken();
  await requestApi('/api/v2/auth/default-wallet', token, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      wallet_address: walletAddress.toLowerCase(),
    }),
  });
  console.log('✓ Default wallet updated.');
  console.log(`  Default wallet: ${walletAddress.toLowerCase()}`);
}

// ── Hyperliquid Info API ──────────────────────────────────────────────────────

async function hlInfoRequest(payload) {
  const options = {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  };
  printVerboseRequest(HL_INFO_URL, options);
  const res = await fetch(HL_INFO_URL, options);
  if (!res.ok) {
    throw new Error(`Hyperliquid API error: HTTP ${res.status}`);
  }
  return res.json();
}

// ── Copy-Trade Commands ──────────────────────────────────────────────────────

function resolveFollowerWallet(userInfo) {
  if (
    userInfo &&
    typeof userInfo.default_wallet_address === 'string' &&
    ETH_ADDR_REGEX.test(userInfo.default_wallet_address)
  ) {
    return userInfo.default_wallet_address.toLowerCase();
  }
  throw new Error('Missing valid default_wallet_address in /api/v2/auth/me');
}

const FOLLOW_OPTION_MAP = {
  mode: 'copy_mode',
  ratio: 'copy_ratio',
  amount: 'fixed_amount',
  size: 'fixed_size',
  slippage: 'max_slippage',
};

function parseFollowOptions(rawArgs) {
  const opts = {};
  const forbiddenKeys = new Set([
    'min_size',
    'max_size',
    'tp',
    'sl',
    'delay',
    'excluded',
    'allowed',
    'leverage',
  ]);
  for (const arg of rawArgs) {
    const eq = arg.indexOf('=');
    if (eq < 1) continue;
    const key = arg.slice(0, eq);
    const val = arg.slice(eq + 1);
    if (forbiddenKeys.has(key)) {
      throw new Error(
        `follow-hl does not allow user-specified "${key}". ` +
          'This field is controlled by backend defaults/policies.'
      );
    }
    const mapped = FOLLOW_OPTION_MAP[key];
    if (!mapped) continue;
    opts[mapped] = val;
  }
  return opts;
}

async function cmdFollowHl(targetWallet, rawArgs) {
  if (!targetWallet || !ETH_ADDR_REGEX.test(targetWallet)) {
    throw new Error('Usage: node auth.mjs follow-hl <target_wallet> [key=val …]');
  }
  const token = requireAccessToken();
  const me = await requestApi('/api/v2/auth/me', token, {
    method: 'GET',
  });
  const userInfo = me && typeof me.data === 'object' && me.data ? me.data : {};
  const followerWallet = resolveFollowerWallet(userInfo);

  const payload = {
    follower_wallet: followerWallet,
    target_wallet: targetWallet.toLowerCase(),
    exchange_type: 'hyperliquid',
    ...parseFollowOptions(rawArgs),
    max_order_size: '10000000',
  };

  const created = await requestApi('/api/v2/copytrade/config', token, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(payload),
  });

  const data =
    created && typeof created.data === 'object' && created.data ? created.data : {};
  console.log('✓ Hyperliquid follow created.');
  if (typeof data.id === 'number') console.log(`  ID: ${data.id}`);
  console.log(`  Follower: ${followerWallet}`);
  console.log(`  Target: ${targetWallet.toLowerCase()}`);
  console.log(`  Mode: ${data.copy_mode ?? payload.copy_mode ?? 'fixed_ratio'}`);
  console.log(`  Ratio: ${data.copy_ratio ?? payload.copy_ratio ?? '1.0'}`);
}

async function cmdFollows() {
  const token = requireAccessToken();
  const res = await requestApi('/api/v2/copytrade/my/configs', token, {
    method: 'GET',
  });
  const configs = Array.isArray(res?.data) ? res.data : [];
  if (configs.length === 0) {
    console.log('No copy-trade configs found.');
    return;
  }
  console.log(`Found ${configs.length} config(s):\n`);
  for (const c of configs) {
    const status = c.is_active ? 'active' : 'paused';
    console.log(`  [${c.id}] ${c.target_wallet} — ${status}`);
    console.log(
      `       Mode: ${c.copy_mode}, Ratio: ${c.copy_ratio}` +
        `, Exchange: ${c.exchange_type}`
    );
    if (c.allowed_coins) {
      console.log(`       Allowed: ${c.allowed_coins}`);
    }
    if (c.excluded_coins) {
      console.log(`       Excluded: ${c.excluded_coins}`);
    }
    console.log();
  }
}

async function cmdFollowToggle(configId) {
  if (!configId) {
    throw new Error('Usage: node auth.mjs follow-toggle <config_id>');
  }
  const token = requireAccessToken();
  const res = await requestApi(`/api/v2/copytrade/config/id/${configId}`, token, {
    method: 'GET',
  });
  const config = res && typeof res.data === 'object' && res.data ? res.data : null;
  if (!config) throw new Error(`Config ${configId} not found`);

  const newStatus = !config.is_active;
  await requestApi(`/api/v2/copytrade/config/${configId}/status`, token, {
    method: 'PATCH',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ is_active: newStatus }),
  });
  const label = newStatus ? 'enabled' : 'disabled';
  console.log(`✓ Config ${configId} ${label}.`);
}

async function cmdFollowDelete(configId) {
  if (!configId) {
    throw new Error('Usage: node auth.mjs follow-delete <config_id>');
  }
  const token = requireAccessToken();
  await requestApi(`/api/v2/copytrade/config/${configId}`, token, {
    method: 'DELETE',
  });
  console.log(`✓ Config ${configId} deleted.`);
}

// ── Hyperliquid Market Commands ──────────────────────────────────────────────

async function cmdHlMarkets() {
  const meta = await hlInfoRequest({ type: 'meta' });
  const universe = meta?.universe ?? [];
  if (universe.length === 0) {
    console.log('No markets found.');
    return;
  }
  console.log(`Hyperliquid Perpetual Markets (${universe.length}):\n`);
  for (const m of universe) {
    console.log(
      `  ${m.name} — szDecimals: ${m.szDecimals}` + `, maxLeverage: ${m.maxLeverage}`
    );
  }
}

async function cmdHlPrice(coin) {
  const mids = await hlInfoRequest({ type: 'allMids' });
  if (coin) {
    const key = coin.toUpperCase();
    const price = mids[key];
    if (price !== undefined) {
      console.log(`${key}: $${price}`);
    } else {
      console.error(`Coin "${key}" not found. Run hl-markets to list coins.`);
      process.exit(1);
    }
  } else {
    const entries = Object.entries(mids);
    console.log(`All mid prices (${entries.length}):\n`);
    for (const [k, v] of entries.sort((a, b) => a[0].localeCompare(b[0]))) {
      console.log(`  ${k}: $${v}`);
    }
  }
}

// ── Hyperliquid Trading Commands (hygo /api/v2/hyperliquid/*) ───────────────

function extractDataField(res) {
  if (res && typeof res === 'object' && 'data' in res) return res.data;
  return res;
}

async function cmdHlOrder(coin, sideInput, size, rawArgs) {
  if (!coin || !sideInput || !size) {
    throw new Error(
      'Usage: node auth.mjs hl-order <coin> <buy|sell> <size> [key=val …]'
    );
  }
  const token = requireAccessToken();
  const opts = parseKeyValueArgs(rawArgs);
  const wallet = await resolveTradingWallet(token, opts.wallet);
  const side = normalizeSide(sideInput);
  const orderType = (opts.type ?? opts.order_type ?? 'market').toLowerCase();
  if (!['market', 'limit'].includes(orderType)) {
    throw new Error('type must be market or limit');
  }
  if (orderType === 'limit' && !opts.price) {
    throw new Error('limit orders require price=...');
  }

  const body = {
    wallet,
    coin,
    side,
    size: String(size),
    order_type: orderType,
  };
  if (opts.price) body.price = String(opts.price);
  if (opts.tif) body.tif = String(opts.tif).toUpperCase();
  if (opts.reduce_only !== undefined) {
    body.reduce_only = parseBool(opts.reduce_only, false);
  }
  if (opts.slippage !== undefined) body.slippage = String(opts.slippage);
  if (opts.cloid) body.cloid = String(opts.cloid);

  const idempotencyKey = opts.idempotency ?? opts.idempotency_key ?? randomUUID();
  const res = await requestApi('/api/v2/hyperliquid/orders', token, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-idempotency-key': idempotencyKey,
    },
    body: JSON.stringify(body),
  });
  const data = extractDataField(res);

  console.log('✓ Hyperliquid order submitted.');
  console.log(`  Wallet: ${wallet}`);
  console.log(`  Coin: ${coin}`);
  console.log(`  Side: ${side}`);
  console.log(`  Size: ${size}`);
  console.log(`  Type: ${orderType}`);
  if (opts.price) console.log(`  Price: ${opts.price}`);
  console.log(`  Idempotency-Key: ${idempotencyKey}`);
  console.log('\nResult:\n' + JSON.stringify(data, null, 2));
}

async function cmdHlCancel(coin, oidOrCloid, rawArgs) {
  if (!coin || !oidOrCloid) {
    throw new Error('Usage: node auth.mjs hl-cancel <coin> <oid|cloid> [wallet=0x…]');
  }
  const token = requireAccessToken();
  const opts = parseKeyValueArgs(rawArgs);
  const wallet = await resolveTradingWallet(token, opts.wallet);

  const cancelItem = { coin };
  if (/^\d+$/.test(oidOrCloid)) {
    cancelItem.oid = Number(oidOrCloid);
  } else {
    cancelItem.cloid = oidOrCloid;
  }

  const res = await requestApi('/api/v2/hyperliquid/orders', token, {
    method: 'DELETE',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      wallet,
      cancels: [cancelItem],
    }),
  });
  const data = extractDataField(res);
  console.log('✓ Cancel request submitted.');
  console.log(`  Wallet: ${wallet}`);
  console.log(`  Coin: ${coin}`);
  if (cancelItem.oid !== undefined) {
    console.log(`  OID: ${cancelItem.oid}`);
  } else {
    console.log(`  CLOID: ${cancelItem.cloid}`);
  }
  console.log('\nResult:\n' + JSON.stringify(data, null, 2));
}

async function cmdHlOpenOrders(walletOrOpt, rawArgs) {
  const token = requireAccessToken();
  const hasWalletArg = walletOrOpt && !walletOrOpt.includes('=');
  const opts = parseKeyValueArgs(hasWalletArg ? rawArgs : [walletOrOpt, ...rawArgs]);
  const wallet = await resolveTradingWallet(
    token,
    hasWalletArg ? walletOrOpt : opts.wallet
  );
  const dex = opts.dex ?? '';
  const q = new URLSearchParams({ wallet });
  if (dex) q.set('dex', dex);

  const res = await requestApi(
    `/api/v2/hyperliquid/open-orders?${q.toString()}`,
    token,
    {
      method: 'GET',
    }
  );
  const data = extractDataField(res);
  const count = Array.isArray(data) ? data.length : 0;
  console.log(`Open orders for ${wallet}: ${count}`);
  console.log(JSON.stringify(data, null, 2));
}

async function cmdHlPerpAccount(walletOrOpt, rawArgs) {
  const token = requireAccessToken();
  const hasWalletArg = walletOrOpt && !walletOrOpt.includes('=');
  const opts = parseKeyValueArgs(hasWalletArg ? rawArgs : [walletOrOpt, ...rawArgs]);
  const wallet = await resolveTradingWallet(
    token,
    hasWalletArg ? walletOrOpt : opts.wallet
  );
  const dex = opts.dex ?? '';
  const q = new URLSearchParams({ wallet });
  if (dex) q.set('dex', dex);

  const res = await requestApi(
    `/api/v2/hyperliquid/perp/account?${q.toString()}`,
    token,
    {
      method: 'GET',
    }
  );
  const data = extractDataField(res);
  console.log(`Perp account for ${wallet}:`);
  console.log(JSON.stringify(data, null, 2));
}

async function cmdHlLeverage(coin, leverage, rawArgs) {
  if (!coin || !leverage) {
    throw new Error(
      'Usage: node auth.mjs hl-leverage <coin> <leverage> [wallet=0x…] [cross=true|false]'
    );
  }
  const levNum = Number(leverage);
  if (!Number.isFinite(levNum) || levNum <= 0) {
    throw new Error('leverage must be a positive number');
  }
  const token = requireAccessToken();
  const opts = parseKeyValueArgs(rawArgs);
  const wallet = await resolveTradingWallet(token, opts.wallet);
  const isCross = parseBool(opts.cross, false);

  const res = await requestApi('/api/v2/hyperliquid/leverage', token, {
    method: 'PUT',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      wallet,
      coin,
      is_cross: isCross,
      leverage: Math.trunc(levNum),
    }),
  });
  const data = extractDataField(res);
  console.log('✓ Leverage updated.');
  console.log(`  Wallet: ${wallet}`);
  console.log(`  Coin: ${coin}`);
  console.log(`  Leverage: ${Math.trunc(levNum)}x`);
  console.log(`  Mode: ${isCross ? 'cross' : 'isolated'}`);
  console.log('\nResult:\n' + JSON.stringify(data, null, 2));
}

// ── Entry ─────────────────────────────────────────────────────────────────────

function errExit(e) {
  console.error('Error:', e.message);
  process.exit(1);
}

switch (cmd) {
  case 'login':
    cmdLogin().catch(errExit);
    break;
  case '_login-server':
    cmdLoginServer();
    break;
  case 'logout':
    cmdLogout();
    break;
  case 'status':
    cmdStatus();
    break;
  case 'token':
    cmdToken();
    break;
  case 'me':
    cmdMe().catch(errExit);
    break;
  case 'set-default-wallet':
    cmdSetDefaultWallet(args[0]).catch(errExit);
    break;
  case 'follow-hl':
    cmdFollowHl(args[0], args.slice(1)).catch(errExit);
    break;
  case 'follows':
    cmdFollows().catch(errExit);
    break;
  case 'follow-toggle':
    cmdFollowToggle(args[0]).catch(errExit);
    break;
  case 'follow-delete':
    cmdFollowDelete(args[0]).catch(errExit);
    break;
  case 'hl-markets':
    cmdHlMarkets().catch(errExit);
    break;
  case 'hl-price':
    cmdHlPrice(args[0]).catch(errExit);
    break;
  case 'hl-order':
    cmdHlOrder(args[0], args[1], args[2], args.slice(3)).catch(errExit);
    break;
  case 'hl-cancel':
    cmdHlCancel(args[0], args[1], args.slice(2)).catch(errExit);
    break;
  case 'hl-open-orders':
    cmdHlOpenOrders(args[0], args.slice(1)).catch(errExit);
    break;
  case 'hl-perp-account':
    cmdHlPerpAccount(args[0], args.slice(1)).catch(errExit);
    break;
  case 'hl-leverage':
    cmdHlLeverage(args[0], args[1], args.slice(2)).catch(errExit);
    break;
  default:
    console.error(`Usage: node auth.mjs <command>

  Auth:
    login          — OAuth flow, save token
    logout         — remove credentials
    status         — auth state and expiry
    token          — print raw access_token
    me             — get current user info and all wallet addresses
    set-default-wallet <wallet_address>
                 — set default wallet via /api/v2/auth/default-wallet

  Hyperliquid Copy-Trade:
    follow-hl <wallet> [key=val …]
                   — create copy-trade config
    follows        — list my configs
    follow-toggle <id>
                   — enable / disable a config
    follow-delete <id>
                   — delete a config

  Hyperliquid Market:
    hl-markets     — list perpetual markets
    hl-price [coin]
                   — mid price(s)
  
  Hyperliquid Trading (hygo):
    hl-order <coin> <buy|sell> <size> [key=val …]
                   — place order via /api/v2/hyperliquid/orders
    hl-cancel <coin> <oid|cloid> [wallet=0x…]
                   — cancel one order via /api/v2/hyperliquid/orders
    hl-open-orders [wallet] [dex=name]
                   — list open orders
    hl-perp-account [wallet] [dex=name]
                   — query perp account state
    hl-leverage <coin> <leverage> [wallet=0x…] [cross=true|false]
                   — update leverage

  follow-hl options (key=val):
    mode=fixed_ratio|fixed_amount|fixed_size
    ratio=1.0  amount=100  size=0.5
    slippage=0.005

  hl-order options (key=val):
    wallet=0x...  type=market|limit  price=1234.5
    tif=GTC|IOC|ALO  reduce_only=true|false
    slippage=0.05  cloid=my-id  idempotency=<key>
`);
    process.exit(1);
}
