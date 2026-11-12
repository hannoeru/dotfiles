#!/bin/sh

# Docs describe the present. Git history holds the past, so tracked
# Markdown must not use words that narrate earlier states. A line can keep
# such a word with an exception marker on the same line:
#   <!-- docs-history: allow until YYYY-MM-DD: REASON -->

set -eu

script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
cd "$script_dir/.."

pattern='formerly|former|previously|used to (be|have|live|exist|run|call)|no longer|that lived|now replaces|was removed|were removed'
today="$(date -u +%Y-%m-%d)"

violations="$(
  git ls-files -z '*.md' | xargs -0 grep -n -i -w -E "$pattern" | awk -v today="$today" '
    match($0, /<!-- docs-history: allow until [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]: [^>]+ -->/) {
      until = substr($0, RSTART + 31, 10)
      if (until >= today) next
      print $0 "  (exception expired on " until ")"
      next
    }
    { print }
  '
)" || true

if [ -n "$violations" ]; then
  printf '%s\n' "$violations"
  cat >&2 <<'EOF'
error: the lines above describe history. State the current fact instead:
write "X does Y", not "X used to do Y" or "X no longer does Z".
Git history holds the past. If a line must keep the word, add on the same line:
  <!-- docs-history: allow until YYYY-MM-DD: REASON -->
EOF
  exit 1
fi
