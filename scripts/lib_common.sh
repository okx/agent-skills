#!/usr/bin/env bash
# Shared helpers for the Skills Marketplace sync pipeline.
#
# Logging: all log output goes to STDERR on purpose, so that scripts which
# emit a value on STDOUT (detect_changed_skills.sh -> skill names,
# pack_skill.sh -> zip path) can be safely consumed via command substitution
# without log lines polluting the captured value.

_ts() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

log()       { printf '%s [INFO]  %s\n'   "$(_ts)" "$*" >&2; }
log_step()  { printf '\n%s [STEP]  ===== %s =====\n' "$(_ts)" "$*" >&2; }
log_warn()  { printf '%s [WARN]  %s\n'   "$(_ts)" "$*" >&2; }
log_error() { printf '%s [ERROR] %s\n'   "$(_ts)" "$*" >&2; }

# Extract the leading YAML frontmatter (content between the first pair of ---).
frontmatter() {
  awk 'BEGIN{c=0} /^---[[:space:]]*$/{c++; next} c==1{print} c>=2{exit}' "$1"
}

# Read a yq path from a SKILL.md frontmatter, e.g. fm_get SKILL.md '.metadata.version'
fm_get() {
  frontmatter "$1" | yq -r "$2"
}

# Fail fast if a required external tool is missing.
require_tool() {
  command -v "$1" >/dev/null 2>&1 || { log_error "required tool not found: $1"; exit 1; }
}
