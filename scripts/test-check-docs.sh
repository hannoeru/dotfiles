#!/bin/sh

# Runs scripts/check-docs.sh against throwaway repositories and checks
# its exit status for each case.

set -eu

script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

# expect STATUS NAME FILE CONTENT: runs the check on a repository whose only
# tracked file is FILE with CONTENT, and expects exit STATUS.
expect() {
  status=$1 name=$2 file=$3 content=$4
  repo="$work/$(printf '%s' "$name" | tr -c 'A-Za-z0-9' '-')"
  mkdir -p "$repo/scripts" "$(dirname "$repo/$file")"
  cp "$script_dir/check-docs.sh" "$repo/scripts/"
  printf '%s\n' "$content" > "$repo/$file"
  git -C "$repo" init -q
  git -C "$repo" add -A
  if "$repo/scripts/check-docs.sh" > "$repo/out.log" 2>&1; then actual=0; else actual=$?; fi
  if [ "$actual" -eq "$status" ]; then
    echo "ok   $name"
  else
    echo "FAIL $name: expected exit $status, got $actual" >&2
    cat "$repo/out.log" >&2
    failures=$((failures + 1))
  fi
}

for phrase in "formerly" "former" "previously" "used to be" "used to run" "no longer" "that lived" "now replaces" "was removed" "were removed"; do
  expect 1 "flags $phrase" docs/a.md "The tool $phrase here."
done
expect 1 "flags any case" README.md "It is NO LONGER here."
expect 1 "flags a nested Markdown file" a/b/c.md "It was removed."

expect 0 "allows present tense" docs/a.md "The tool builds the image."
expect 0 "allows 'used to' as a purpose" docs/a.md "This flag is used to build images."
expect 0 "allows a word that only contains a pattern" docs/a.md "The reformerly-named field."
expect 0 "ignores files that are not Markdown" a.txt "It was removed."

expect 0 "allows a line with a valid exception" docs/a.md \
  "It was removed. <!-- docs-history: allow until 2999-01-01: release notes -->"
expect 1 "rejects an expired exception" docs/a.md \
  "It was removed. <!-- docs-history: allow until 2000-01-01: release notes -->"
expect 1 "rejects an exception without a reason" docs/a.md \
  "It was removed. <!-- docs-history: allow until 2999-01-01 -->"
expect 1 "rejects an exception on another line" docs/a.md \
  "<!-- docs-history: allow until 2999-01-01: release notes -->
It was removed."

untracked="$work/untracked"
mkdir -p "$untracked/scripts"
cp "$script_dir/check-docs.sh" "$untracked/scripts/"
git -C "$untracked" init -q
printf 'It was removed.\n' > "$untracked/a.md"
if "$untracked/scripts/check-docs.sh" > /dev/null 2>&1; then echo "ok   ignores untracked Markdown"; else
  echo "FAIL ignores untracked Markdown" >&2
  failures=$((failures + 1))
fi

[ "$failures" -eq 0 ]
