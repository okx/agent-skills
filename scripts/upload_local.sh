#!/usr/bin/env bash
# upload_local.sh — pack & upload official skills to the Skills Marketplace.
# Self-contained: the only other file it needs is skills_sync.sh (the signed
# login + priapi upload). Run this one script to achieve the goal.
#
# 1) Provide the non-2FA test account JSON via the project .env (never commit it).
#    Copy .env.example to .env and fill in the value:
#      SKILLS_MP_TEST_USER='{"loginName":"you@okg.com","password":"...","passwordHash":"..."}'
#    (.env is gitignored. A pre-exported env var still overrides the .env file.)
#
# 2) Run one of:
#      scripts/upload_local.sh okx-cex-trade                # one or more skills by name
#      scripts/upload_local.sh okx-cex-trade okx-cex-bot
#      scripts/upload_local.sh --all                        # every skill under skills/
#      DRY_RUN=1 scripts/upload_local.sh --all              # plan only: query remote, print create/update/skip, do NOT upload
#      KEEP_DIST=1 scripts/upload_local.sh --all            # keep dist/ artifacts (skip cleanup)
#
# Per skill the remote version is queried first to decide the action:
#   first upload (not on remote) / incremental update / skip (already up-to-date).
# DRY_RUN reports that plan without uploading — it still logs in and queries the
# remote, so SKILLS_MP_TEST_USER is required in dry-run too.
#
# Cleanup: the dist/<name>/ staging dir is removed right after zipping; on a
# successful upload the zip is deleted too. DRY_RUN keeps zips for inspection.
# Set KEEP_DIST=1 to keep everything.
#
# Requires: bash, yq (mikefarah v4), jq, zip, openssl, curl, git.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SELF="$HERE/$(basename "$0")"   # absolute path to this script (survives the cd below)
cd "$(git rev-parse --show-toplevel)"

SKILLS_DIR="${SKILLS_DIR:-skills}"
OUT_DIR="${OUT_DIR:-dist}"
SYNC_SCRIPT="${SYNC_SCRIPT:-$HERE/skills_sync.sh}"
DRY_RUN="${DRY_RUN:-0}"

# ---- load credentials from project .env (gitignored; never committed) -------
# A pre-set environment variable always wins over the .env file.
ENV_FILE="${ENV_FILE:-.env}"
if [ -z "${SKILLS_MP_TEST_USER:-}" ] && [ -f "$ENV_FILE" ]; then
  set -a; . "$ENV_FILE"; set +a
fi

# ---- logging (to stderr, so stdout stays clean for captured values) ---------
_ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log()       { printf '%s [INFO]  %s\n'   "$(_ts)" "$*" >&2; }
log_step()  { printf '\n%s [STEP]  ===== %s =====\n' "$(_ts)" "$*" >&2; }
log_warn()  { printf '%s [WARN]  %s\n'   "$(_ts)" "$*" >&2; }
log_error() { printf '%s [ERROR] %s\n'   "$(_ts)" "$*" >&2; }
require_tool() { command -v "$1" >/dev/null 2>&1 || { log_error "required tool not found: $1"; exit 1; }; }

# ---- SKILL.md frontmatter parsing -------------------------------------------
frontmatter() { awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; next} c==1{print} c>=2{exit}' "$1"; }
fm_get()      { frontmatter "$1" | yq -r "$2"; }

# ---- category map (auth/market/portfolio intentionally have no category) ----
category_for() {
  case "$1" in
    okx-cex-trade|okx-cex-skill-mp)            echo "execute" ;;
    okx-cex-bot|okx-cex-earn)                  echo "strategy" ;;
    okx-cex-smartmoney|okx-sentiment-tracker)  echo "news" ;;
    *)                                         echo "" ;;
  esac
}

usage() { awk 'NR>=2 && /^#/{sub(/^# ?/,""); print; next} NR>=2{exit}' "$SELF"; exit "${1:-0}"; }

# ---- pack one skill into dist/<name>-<version>.zip; echoes the zip path ------
pack_skill() {
  local name="$1" src="$SKILLS_DIR/$1" version desc title categories stage zipfile
  [ -f "$src/SKILL.md" ] || { log_error "missing $src/SKILL.md"; return 1; }
  version="$(fm_get "$src/SKILL.md" '.metadata.version')"
  [ -n "$version" ] && [ "$version" != "null" ] || { log_error "$name: no metadata.version"; return 1; }
  desc="$(fm_get "$src/SKILL.md" '.description')"
  title="$name"                       # TITLE kept identical to name
  categories="$(category_for "$name")"
  log "pack $name v$version (categories='${categories:-<none>}')"
  stage="$OUT_DIR/$name"; rm -rf "$stage"; mkdir -p "$stage"
  cp -R "$src/." "$stage/"
  jq -n --arg name "$name" --arg title "$title" --arg desc "$desc" \
        --arg version "$version" --arg cat "$categories" \
    '{name:$name, title:$title, description:$desc, version:$version, categories:$cat}' \
    > "$stage/_meta.json"
  zipfile="$OUT_DIR/${name}-${version}.zip"; rm -f "$zipfile"
  ( cd "$stage" && zip -rq "$OLDPWD/$zipfile" . )
  [ "${KEEP_DIST:-0}" = "1" ] || rm -rf "$stage"   # drop the intermediate unzipped copy
  printf '%s\n' "$zipfile"
}

# ---- resolve targets --------------------------------------------------------
[ $# -ge 1 ] || usage 1
for t in yq jq zip git; do require_tool "$t"; done

SELECTOR="${1:-}"
log_step "Resolve targets (selector='$SELECTOR', dry_run=$DRY_RUN)"
declare -a TARGETS=()
case "$SELECTOR" in
  -h|--help) usage 0 ;;
  --all)     log "mode --all: selecting every skill under $SKILLS_DIR/"
             for d in "$SKILLS_DIR"/*/; do [ -f "${d%/}/SKILL.md" ] && TARGETS+=("$(basename "$d")"); done ;;
  -*)        log_error "unknown option: $1"; usage 1 ;;
  *)         log "mode explicit: $*"
             for name in "$@"; do
               [ -f "$SKILLS_DIR/$name/SKILL.md" ] && TARGETS+=("$name") \
                 || { log_error "no such skill: $SKILLS_DIR/$name/SKILL.md"; exit 1; }
             done ;;
esac

if [ "${#TARGETS[@]}" -eq 0 ]; then
  log_warn "no target skills resolved — nothing to do"
  exit 0
fi
log "resolved ${#TARGETS[@]} target(s): ${TARGETS[*]}"

# ---- credentials (required for both dry-run and real upload) ----------------
# Dry-run also logs in and queries the remote to decide create/update/skip, so
# credentials are needed in both modes.
if [ -z "${SKILLS_MP_TEST_USER:-}" ]; then
  log_error "SKILLS_MP_TEST_USER is not set. Add it to $ENV_FILE (copy .env.example), e.g.:"
  log_error "  SKILLS_MP_TEST_USER='{\"loginName\":\"you@okg.com\",\"password\":\"...\",\"passwordHash\":\"...\"}'"
  exit 1
fi
export USER="$SKILLS_MP_TEST_USER"
export BODY="$USER"   # skills_sync.sh signs over BODY; must equal the posted login body
log "credentials loaded from SKILLS_MP_TEST_USER"

# ---- batch login: log in ONCE, reuse the token for every skill --------------
# The token is passed to per-skill calls via the exported TOKEN env var (never
# on a command line). skills_sync.sh writes it to TOKEN_FILE (chmod 600) so it
# never transits stdout; we read it, export it, then delete the file.
log "logging in once; token will be reused for all ${#TARGETS[@]} skill(s)"
TOKEN_FILE="$(mktemp)"; chmod 600 "$TOKEN_FILE"
trap 'rm -f "$TOKEN_FILE"' EXIT
TOKEN_FILE="$TOKEN_FILE" bash "$SYNC_SCRIPT" get_token >&2 \
  || { log_error "batch login failed"; exit 1; }
TOKEN="$(cat "$TOKEN_FILE")"
rm -f "$TOKEN_FILE"; trap - EXIT
[ -n "$TOKEN" ] || { log_error "batch login produced no token"; exit 1; }
export TOKEN
log "login OK; token cached for the batch (skills_sync.sh will reuse it)"

# scratch file skills_sync.sh writes the resolved remote version into (per skill)
VER_FILE="$(mktemp)"; trap 'rm -f "$VER_FILE"' EXIT

declare -a SYNCED=() SKIPPED=() FAILED=()

declare -i idx=0
for name in "${TARGETS[@]}"; do
  idx+=1
  log_step "Processing $name ($idx/${#TARGETS[@]})"

  log "[stage 1/3] pack $name -> zip"
  zip_path="$(pack_skill "$name")"
  VERSION="$(fm_get "$SKILLS_DIR/$name/SKILL.md" '.metadata.version')"
  log "[stage 1/3] packed $name v$VERSION -> $zip_path"

  export NAME="$name"
  export TITLE="$name"
  export DESC="$(fm_get "$SKILLS_DIR/$name/SKILL.md" '.description')"
  export VERSION
  export CATEGORIES="$(category_for "$name")"
  export FILE_PATH="$zip_path"

  # skills_sync.sh queries the remote version first, then either uploads (first
  # time), updates (incremental) or skips (up-to-date). DRY_RUN reports the plan
  # without uploading. Exit: 0 done/planned, 2 skipped up-to-date, else failed.
  if [ "$DRY_RUN" = "1" ]; then log "[stage 2/3] query remote + decide (DRY_RUN: plan only) for $name v$VERSION ..."
  else                          log "[stage 2/3] query remote + decide + upload for $name v$VERSION ..."; fi
  printf '__UNSET__' > "$VER_FILE"   # sentinel: distinguishes "no remote query" from a real empty version
  set +e; DRY_RUN="$DRY_RUN" VERSION_OUT="$VER_FILE" bash "$SYNC_SCRIPT"; rc=$?; set -e

  remote_ver="$(cat "$VER_FILE" 2>/dev/null || true)"
  case "$remote_ver" in
    __UNSET__) remote_label="unknown (remote not queried / error before lookup)" ;;
    -1)        remote_label="not on remote — first upload" ;;
    "")         remote_label="exists on remote, no approved version yet" ;;
    *)         remote_label="v$remote_ver" ;;
  esac
  log "[stage 3/3] $name: remote version = ${remote_label}; local = v$VERSION; skills_sync.sh exit=$rc"

  case "$rc" in
    0) if [ "$DRY_RUN" = "1" ]; then log "PLANNED: $name v$VERSION (create/update)"; SKIPPED+=("$name v$VERSION (dry-run)")
       else log "OK: $name v$VERSION"; SYNCED+=("$name v$VERSION")
            [ "${KEEP_DIST:-0}" = "1" ] || { rm -f "$zip_path"; log "cleaned $zip_path"; }
       fi ;;
    2) log "SKIP: $name v$VERSION already up-to-date remotely"; SKIPPED+=("$name v$VERSION (up-to-date)")
       { [ "${KEEP_DIST:-0}" = "1" ] || [ "$DRY_RUN" = "1" ]; } || rm -f "$zip_path" ;;
    *) log_error "$name v$VERSION failed (exit $rc); kept $zip_path for debugging"; FAILED+=("$name v$VERSION (exit $rc)") ;;
  esac
done

log_step "Summary"
log "synced  (${#SYNCED[@]}): ${SYNCED[*]:-none}"
log "skipped (${#SKIPPED[@]}): ${SKIPPED[*]:-none}"
log "failed  (${#FAILED[@]}): ${FAILED[*]:-none}"
[ "${KEEP_DIST:-0}" = "1" ] || rmdir "$OUT_DIR" 2>/dev/null || true   # remove dist/ only if now empty
[ "${#FAILED[@]}" -eq 0 ] || { log_error "one or more uploads failed"; exit 1; }
log "done"
