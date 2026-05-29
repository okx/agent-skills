#!/usr/bin/env bash
# Package a single skill into dist/<name>-<version>.zip in the format expected
# by the Skills Marketplace upload script:
#
#   <name>-<version>.zip
#   ├── SKILL.md
#   ├── _meta.json      (generated here)
#   └── references/     (copied as-is, if present)
#
# Prints the resulting zip path on STDOUT; all logs go to STDERR.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib_common.sh"
require_tool yq
require_tool jq
require_tool zip

NAME="${1:?usage: pack_skill.sh <skill-name>}"
SKILLS_DIR="${SKILLS_DIR:-skills}"
OUT_DIR="${OUT_DIR:-dist}"
CAT_MAP="${CAT_MAP:-$HERE/skill-categories.json}"
SRC="$SKILLS_DIR/$NAME"

log_step "Packing skill: $NAME"
[ -d "$SRC" ] || { log_error "skill not found: $SRC"; exit 1; }
[ -f "$SRC/SKILL.md" ] || { log_error "missing $SRC/SKILL.md"; exit 1; }

VERSION="$(fm_get "$SRC/SKILL.md" '.metadata.version')"
[ -n "$VERSION" ] && [ "$VERSION" != "null" ] || { log_error "$NAME: no metadata.version"; exit 1; }
DESC="$(fm_get "$SRC/SKILL.md" '.description')"
# TITLE is kept identical to the skill name per product decision.
TITLE="$NAME"
CATEGORIES="$(jq -r --arg n "$NAME" '.[$n] // ""' "$CAT_MAP")"
[ "$CATEGORIES" = "null" ] && CATEGORIES=""

log "version    : $VERSION"
log "title      : $TITLE"
log "categories : ${CATEGORIES:-<none>}"

stage="$OUT_DIR/$NAME"
log "staging    : $stage"
rm -rf "$stage"
mkdir -p "$stage"
cp -R "$SRC/." "$stage/"

log "writing _meta.json"
jq -n \
  --arg name "$NAME" \
  --arg title "$TITLE" \
  --arg desc "$DESC" \
  --arg version "$VERSION" \
  --arg cat "$CATEGORIES" \
  '{name:$name, title:$title, description:$desc, version:$version, categories:$cat}' \
  > "$stage/_meta.json"

zipfile="$OUT_DIR/${NAME}-${VERSION}.zip"
rm -f "$zipfile"
log "zipping     -> $zipfile"
( cd "$stage" && zip -rq "$OLDPWD/$zipfile" . )

log "packed $NAME v$VERSION ($(du -h "$zipfile" | cut -f1))"
printf '%s\n' "$zipfile"   # <-- machine-readable output on STDOUT
