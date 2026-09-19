#!/usr/bin/env bash

# Shared utility for the remote branch/PR/issue workflow. Imported by remote.sh.

create_herdr_workspace() {
  local wtpath label herdr root_ws

  wtpath=$1
  label=$2
  herdr=${HERDR_BIN_PATH:-herdr}

  root_ws=$("$herdr" worktree list --cwd "$PWD" --json 2>/dev/null |
    jq -r '.result.source.source_workspace_id // empty')
  [[ -z "$root_ws" ]] && root_ws=$HERDR_WORKSPACE_ID

  "$herdr" worktree open --workspace "$root_ws" \
    --path "$wtpath" --label "$label" --focus 2>/dev/null || {
    printf '\033[33mWarning:\033[0m herdr worktree open failed for %s\n' "$wtpath" >&2
  }
}
