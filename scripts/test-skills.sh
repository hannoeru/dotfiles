#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

skills=$(nix build --impure --no-link --print-out-paths --file tests/skills-module.nix skills)
python=$(nix build --impure --no-link --print-out-paths --file tests/skills-module.nix python3)
wrapper=$(nix build --impure --no-link --print-out-paths --file tests/skills-module.nix wrapper)
printf 'Native CLI: %s\nGenerated command: %s\n' "$skills/bin/skills" "$wrapper/bin/dotfiles-skills-sync"

SKILLS_BIN="$skills/bin/skills" "$python/bin/python3" tests/test-skills-sync.py

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
HOME="$scratch" \
  XDG_STATE_HOME="$scratch/.local/state" \
  XDG_CONFIG_HOME="$scratch/.config" \
  XDG_DATA_HOME="$scratch/.local/share" \
  XDG_CACHE_HOME="$scratch/.cache" \
  "$wrapper/bin/dotfiles-skills-sync"
grep -Fq 'name: fixture-skill' "$scratch/.agents/skills/fixture/fixture-skill/SKILL.md"
test -L "$scratch/.agents/skills/fixture"

if nix eval --impure --json --file tests/skills-module.nix sources \
  --argstr category "../unsafe" > "$scratch/invalid-category.log" 2>&1; then
  echo "Invalid category unexpectedly passed Nix evaluation" >&2
  exit 1
fi
grep -Fq 'string matching the pattern' "$scratch/invalid-category.log"
printf 'Enabled module command and invalid-category evaluation passed.\n'
