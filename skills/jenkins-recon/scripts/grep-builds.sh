#!/bin/bash
# Check a list of Jenkins build URLs for an exact string in their console output.
#
# Usage:
#   grep-builds.sh <urls-file> <exact-pattern> <matches-out-file> [parallelism]
#
# <urls-file>: one build URL per line (with or without trailing slash/consoleText)
# <exact-pattern>: fixed string (not a regex) to grep for — use the specific
#   failure line, not just an artifact filename (see SKILL.md).
# Writes matching URLs to <matches-out-file>. Any curl errors go to
# <matches-out-file>.errors alongside it.
#
# Designed to avoid BSD-xargs pitfalls: no `xargs -a`, and the per-URL logic
# lives in this file rather than an inline `xargs -I{} bash -c '...'`, which
# can hit "command line cannot be assembled, too long" on macOS.

set -euo pipefail

urls_file="$1"
pattern="$2"
out_file="$3"
parallelism="${4:-8}"
err_file="${out_file}.errors"

: > "$out_file"
: > "$err_file"

check_one() {
  local url="$1"
  # Normalize: strip trailing slash, then append consoleText.
  url="${url%/}/consoleText"
  local content
  content=$(curl -sS --max-time 20 "$url" 2>>"$err_file") || return 0
  if grep -qF -- "$pattern" <<<"$content"; then
    echo "$url" >> "$out_file"
  fi
}
export -f check_one
export pattern out_file err_file

cat "$urls_file" | xargs -P "$parallelism" -I{} bash -c 'check_one "$@"' _ {}

echo "Matches: $(wc -l < "$out_file" | tr -d ' ')"
