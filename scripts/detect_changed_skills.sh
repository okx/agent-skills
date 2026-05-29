#!/usr/bin/env bash
# Detect which skills had their metadata.version changed vs the previous commit.
# Prints one changed skill directory name per line on STDOUT.
# All diagnostics go to STDERR (see lib_common.sh).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib_common.sh"
require_tool yq
require_tool git

SKILLS_DIR="${SKILLS_DIR:-skills}"
BASE_REF="${CI_COMMIT_BEFORE_SHA:-HEAD~1}"

log_step "Detecting version-changed skills"
log "skills dir : $SKILLS_DIR"

# Handle first push / all-zero SHA / missing parent.
if ! git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null 2>&1; then
  log_warn "base ref '$BASE_REF' not resolvable, falling back to HEAD~1"
  BASE_REF="HEAD~1"
fi
if ! git rev-parse --verify --quiet "${BASE_REF}^{commit}" >/dev/null 2>&1; then
  log_warn "no previous commit available; treating all current versions as new"
  BASE_REF=""
fi
log "base ref   : ${BASE_REF:-<none>}"

# Read metadata.version for a SKILL.md at a given git ref ("" = working tree).
version_at_ref() {
  local ref="$1" path="$2"
  if [ -z "$ref" ]; then
    [ -f "$path" ] || return 0
    frontmatter "$path" | yq -r '.metadata.version // ""' 2>/dev/null || true
  else
    git show "$ref:$path" 2>/dev/null \
      | awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++;next} c==1{print} c>=2{exit}' \
      | yq -r '.metadata.version // ""' 2>/dev/null || true
  fi
}

changed_count=0
scanned_count=0
for dir in "$SKILLS_DIR"/*/; do
  name="$(basename "$dir")"
  md="${dir%/}/SKILL.md"   # strip trailing slash from the glob so git show gets a clean path
  [ -f "$md" ] || { log "skip $name (no SKILL.md)"; continue; }
  scanned_count=$((scanned_count + 1))

  new_v="$(version_at_ref "" "$md")"
  old_v="$(version_at_ref "$BASE_REF" "$md")"

  if [ -z "$new_v" ]; then
    log_warn "$name: no metadata.version found, skipping"
    continue
  fi

  if [ "$new_v" != "$old_v" ]; then
    log "CHANGED  $name: '${old_v:-<none>}' -> '$new_v'"
    changed_count=$((changed_count + 1))
    printf '%s\n' "$name"   # <-- machine-readable output on STDOUT
  else
    log "unchanged $name: $new_v"
  fi
done

log "scanned $scanned_count skill(s); $changed_count changed"
