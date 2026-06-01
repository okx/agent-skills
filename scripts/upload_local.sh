#!/usr/bin/env bash
# upload_local.sh — pack & upload official skills to the Skills Marketplace.
# Self-contained: the only other file it needs is skills_sync.sh (the signed
# login + priapi upload). Run this one script to achieve the goal.
#
# 1) Export the non-2FA test account JSON (never commit this value):
#      export SKILLS_MP_TEST_USER='{"loginName":"you@okg.com","password":"...","passwordHash":"..."}'
#
# 2) Run one of:
#      scripts/upload_local.sh okx-cex-trade                # one or more skills by name
#      scripts/upload_local.sh okx-cex-trade okx-cex-bot
#      scripts/upload_local.sh --all                        # every skill under skills/
#      scripts/upload_local.sh --changed                    # only version-changed vs previous commit
#      DRY_RUN=1 scripts/upload_local.sh --all              # pack only, do NOT upload
#      KEEP_DIST=1 scripts/upload_local.sh --all            # keep dist/ artifacts (skip cleanup)
#
# Cleanup: the dist/<name>/ staging dir is removed right after zipping; on a
# successful upload the zip is deleted too. DRY_RUN keeps zips for inspection.
# Set KEEP_DIST=1 to keep everything.
#
# Requires: bash, yq (mikefarah v4), jq, zip, openssl, curl, git.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$(git rev-parse --show-toplevel)"

SKILLS_DIR="${SKILLS_DIR:-skills}"
OUT_DIR="${OUT_DIR:-dist}"
SYNC_SCRIPT="${SYNC_SCRIPT:-$HERE/skills_sync.sh}"
DRY_RUN="${DRY_RUN:-0}"

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

usage() { awk 'NR>=2 && /^#/{sub(/^# ?/,""); print; next} NR>=2{exit}' "$0"; exit "${1:-0}"; }

# ---- change detection (only used by --changed) ------------------------------
version_at_ref() {  # $1=ref ("" = working tree)  $2=path
  local ref="$1" path="$2"
  if [ -z "$ref" ]; then
    [ -f "$path" ] && frontmatter "$path" | yq -r '.metadata.version // ""' 2>/dev/null || true
  else
    git show "$ref:$path" 2>/dev/null \
      | awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++;next} c==1{print} c>=2{exit}' \
      | yq -r '.metadata.version // ""' 2>/dev/null || true
  fi
}
detect_changed() {  # prints version-changed skill names to stdout
  local base="${CI_COMMIT_BEFORE_SHA:-HEAD~1}" dir name md new_v old_v
  git rev-parse --verify --quiet "${base}^{commit}" >/dev/null 2>&1 || base="HEAD~1"
  git rev-parse --verify --quiet "${base}^{commit}" >/dev/null 2>&1 || base=""
  log "change base ref: ${base:-<none>}"
  for dir in "$SKILLS_DIR"/*/; do
    name="$(basename "$dir")"; md="${dir%/}/SKILL.md"
    [ -f "$md" ] || continue
    new_v="$(version_at_ref "" "$md")"; old_v="$(version_at_ref "$base" "$md")"
    [ -n "$new_v" ] || continue
    if [ "$new_v" != "$old_v" ]; then log "CHANGED $name: '${old_v:-<none>}' -> '$new_v'"; printf '%s\n' "$name"
    else log "unchanged $name: $new_v"; fi
  done
}

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

declare -a TARGETS=()
case "${1:-}" in
  -h|--help) usage 0 ;;
  --all)     for d in "$SKILLS_DIR"/*/; do [ -f "${d%/}/SKILL.md" ] && TARGETS+=("$(basename "$d")"); done ;;
  --changed) while IFS= read -r n; do [ -n "$n" ] && TARGETS+=("$n"); done < <(detect_changed) ;;
  -*)        log_error "unknown option: $1"; usage 1 ;;
  *)         for name in "$@"; do
               [ -f "$SKILLS_DIR/$name/SKILL.md" ] && TARGETS+=("$name") \
                 || { log_error "no such skill: $SKILLS_DIR/$name/SKILL.md"; exit 1; }
             done ;;
esac

log_step "Local upload (dry_run=$DRY_RUN)"
[ "${#TARGETS[@]}" -gt 0 ] || { log_warn "no target skills resolved — nothing to do"; exit 0; }
log "targets: ${TARGETS[*]}"

# ---- credentials (real upload only) -----------------------------------------
if [ "$DRY_RUN" != "1" ]; then
  if [ -z "${SKILLS_MP_TEST_USER:-}" ]; then
    log_error "SKILLS_MP_TEST_USER is not set. Export it first, e.g.:"
    log_error "  export SKILLS_MP_TEST_USER='{\"loginName\":\"you@okg.com\",\"password\":\"...\",\"passwordHash\":\"...\"}'"
    exit 1
  fi
  export USER="$SKILLS_MP_TEST_USER"
  export BODY="$USER"   # skills_sync.sh signs over BODY; must equal the posted login body
  log "credentials loaded from SKILLS_MP_TEST_USER"
fi

declare -a SYNCED=() SKIPPED=() FAILED=()

for name in "${TARGETS[@]}"; do
  log_step "Processing $name"
  zip_path="$(pack_skill "$name")"
  VERSION="$(fm_get "$SKILLS_DIR/$name/SKILL.md" '.metadata.version')"

  if [ "$DRY_RUN" = "1" ]; then
    log "DRY_RUN: would upload $name v$VERSION from $zip_path"
    SKIPPED+=("$name v$VERSION (dry-run)"); continue
  fi

  export NAME="$name"
  export TITLE="$name"
  export DESC="$(fm_get "$SKILLS_DIR/$name/SKILL.md" '.description')"
  export VERSION
  export CATEGORIES="$(category_for "$name")"
  export FILE_PATH="$zip_path"

  log "uploading $name v$VERSION ..."
  set +e; bash "$SYNC_SCRIPT"; rc=$?; set -e
  case "$rc" in
    0) log "OK: $name v$VERSION"; SYNCED+=("$name v$VERSION")
       [ "${KEEP_DIST:-0}" = "1" ] || { rm -f "$zip_path"; log "cleaned $zip_path"; } ;;
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
