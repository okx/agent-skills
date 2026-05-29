#!/usr/bin/env bash
# Orchestrator: detect version-changed skills -> pack each -> upload via the
# Skills Marketplace sync script. Designed to run in GitLab CI on the
# github-main / github-main-test-mp branches.
#
# Required env (from CI secrets):
#   SKILLS_MP_TEST_USER  JSON: {"loginName","password","passwordHash"} for the
#                        non-2FA test account; assigned to USER for skills_sync.sh.
# Optional env:
#   DRY_RUN=1            Pack only; do not call skills_sync.sh.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib_common.sh"
cd "$(git rev-parse --show-toplevel)"

SYNC_SCRIPT="${SYNC_SCRIPT:-$HERE/skills_sync.sh}"
DRY_RUN="${DRY_RUN:-0}"

log_step "Skills Marketplace sync started"
log "repo root  : $(pwd)"
log "branch     : ${CI_COMMIT_BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
log "dry run    : $DRY_RUN"

# --- 1. Detect changed skills -------------------------------------------------
CHANGED=()
while IFS= read -r _line; do
  [ -n "$_line" ] && CHANGED+=("$_line")
done < <(bash "$HERE/detect_changed_skills.sh")
if [ "${#CHANGED[@]}" -eq 0 ]; then
  log_step "No skill version changes detected — nothing to sync"
  exit 0
fi
log "to sync    : ${CHANGED[*]}"

# --- 2. Credentials (only needed for a real upload) ---------------------------
if [ "$DRY_RUN" != "1" ]; then
  export USER="${SKILLS_MP_TEST_USER:?missing CI secret SKILLS_MP_TEST_USER}"
  # skills_sync.sh signs over $BODY and posts $USER as the login body; they must be equal.
  export BODY="$USER"
  log "credentials: loaded from SKILLS_MP_TEST_USER (masked)"
fi

declare -a SYNCED=() SKIPPED=() FAILED=()

# --- 3. Pack + upload each changed skill -------------------------------------
for name in "${CHANGED[@]}"; do
  log_step "Processing $name"

  zip_path="$(bash "$HERE/pack_skill.sh" "$name")"

  VERSION="$(fm_get "skills/$name/SKILL.md" '.metadata.version')"
  DESC="$(fm_get "skills/$name/SKILL.md" '.description')"
  CATEGORIES="$(jq -r --arg n "$name" '.[$n] // ""' "$HERE/skill-categories.json")"
  [ "$CATEGORIES" = "null" ] && CATEGORIES=""

  if [ "$DRY_RUN" = "1" ]; then
    log "DRY_RUN: would upload $name v$VERSION (categories='${CATEGORIES:-<none>}') from $zip_path"
    SKIPPED+=("$name v$VERSION (dry-run)")
    continue
  fi

  # Env contract expected by skills_sync.sh. TITLE is kept identical to NAME.
  export NAME="$name"
  export TITLE="$name"
  export DESC
  export VERSION
  export FILE_PATH="$zip_path"
  # CATEGORIES is optional; pass an empty string (not unset) for no-category skills,
  # because skills_sync.sh always references $CATEGORIES under `set -u`.
  export CATEGORIES
  [ -n "$CATEGORIES" ] || log "$name: no category assigned — sending empty categories"

  log "uploading $name v$VERSION ..."
  set +e
  bash "$SYNC_SCRIPT"
  rc=$?
  set -e

  case "$rc" in
    0)
      log "OK: $name v$VERSION uploaded"
      SYNCED+=("$name v$VERSION")
      ;;
    20)
      # No-overwrite policy: marketplace already has this (name,version).
      log_warn "$name v$VERSION already published — skipped (same-version overwrite not allowed)"
      SKIPPED+=("$name v$VERSION (already published)")
      ;;
    *)
      log_error "$name v$VERSION upload failed (exit $rc)"
      FAILED+=("$name v$VERSION (exit $rc)")
      ;;
  esac
done

# --- 4. Summary ---------------------------------------------------------------
log_step "Sync summary"
log "synced  (${#SYNCED[@]}): ${SYNCED[*]:-none}"
log "skipped (${#SKIPPED[@]}): ${SKIPPED[*]:-none}"
log "failed  (${#FAILED[@]}): ${FAILED[*]:-none}"

if [ "${#FAILED[@]}" -gt 0 ]; then
  log_error "one or more skills failed to sync"
  exit 1
fi
log "Skills Marketplace sync finished successfully"
