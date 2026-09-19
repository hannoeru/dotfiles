#!/usr/bin/env bash
# Worktrunk herdr plugin — pull remote branches, PRs, and issues into a herdr
# workspace via worktrunk + gh + fzf. State machine: MENU, ISSUE_PICK, BRANCH,
# BRANCH_CONFLICT, REMOTE, PR.

set -uo pipefail
IFS=$'\n\t'

plugin_root=${HERDR_PLUGIN_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}
# shellcheck source=./helpers.sh
source "$plugin_root/helpers.sh"
# shellcheck source=./remote-helpers.sh
source "$plugin_root/remote-helpers.sh"

for tool in fzf gh jq wt; do
  command -v "$tool" >/dev/null && continue
  printf '\033[31m%s required — install it first\033[0m\n' "$tool" >&2
  exit 1
done

# herdr panes may not have stdin on /dev/tty
prompt() {
  printf '%s ' "$*" >&2
  read -r </dev/tty || true
  printf '%s' "$REPLY"
}
prompt_any_key() {
  printf '\033[33m%s\033[0m' 'Press any key to continue' >&2
  read -rn1 </dev/tty || true
  printf '\n' >&2
}

fzf_pick() {
  local prompt_text=$1 header_text=$2
  shift 2
  fzf --print-query --reverse --info=inline --border=rounded --margin=20%,30% \
    --prompt="$prompt_text " \
    --header="$header_text" \
    "$@"
}
say() { printf '\033[36m▶ %s\033[0m\n' "$*" >&2; }
ok() { printf '\033[36m  ✓ %s\033[0m\n' "$*" >&2; }

# Cap a command with `timeout`/`gtimeout` when one exists (GNU coreutils or
# Homebrew); otherwise run it directly. macOS ships neither and they aren't
# Nix-installed, so this keeps gh/wt working on a fresh machine while still
# capping them where a timeout binary is present.
run_timeout() {
  local secs=$1
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    "$@"
  fi
}

pulldown() {
  local branch=$1 label=$2
  say "switching to $branch"

  # Worktrunk shortcuts (pr:N/mr:N/URLs, ^, -) and refs that already exist
  # locally or under origin never use --create.
  if worktrunk_is_shortcut "$branch"; then
    wtargs=(switch "$branch")
  elif git show-ref --quiet --verify "refs/heads/$branch" 2>/dev/null \
    || git show-ref --quiet --verify "refs/remotes/origin/$branch" 2>/dev/null; then
    wtargs=(switch "$branch")
  else
    wtargs=(switch --create "$branch")
  fi

  run_timeout 15 wt "${wtargs[@]}" --no-cd 2>/dev/null || {
    printf '\033[31mwt switch failed — press any key to continue\033[0m\n' >&2
    prompt_any_key
    return 1
  }

  # wt list emits JSON schema 1 (a bare array) by default; normalize both schemas
  # through the shared helper before selecting the worktree path.
  local wtpath
  if [[ $branch == *:* ]]; then
    # shortcut resolves to the actual branch — take the newest worktree
    wtpath=$(wt list --format=json 2>/dev/null | worktrunk_list_items |
      jq -r 'select(.kind == "worktree") | .path' | tail -n1)
  else
    wtpath=$(wt list --format=json 2>/dev/null | worktrunk_list_items |
      jq -r --arg b "$branch" 'select(.branch == $b and .kind == "worktree") | .path' | head -n1)
  fi

  if [[ -z $wtpath ]]; then
    printf '\033[31mCould not find worktree path for %s — press any key\033[0m\n' "$branch" >&2
    prompt_any_key
    return 1
  fi

  say "registering workspace: $label ($wtpath)"
  create_herdr_workspace "$wtpath" "$label"
  ok "done: $label"
  exit 0
}

_issue_n_from_url() {
  local url=$1
  printf '%s' "$url" | sed -nE 's|.*/issues/([0-9]+).*|\1|p'
}

state=MENU
issue_n=

while true; do
  case $state in

  MENU)
    mode=$(printf 'issue\nremote branch\npr' |
      fzf_pick 'remote ❯' 'enter picks mode  ·  esc exits')
    ret=$?
    [[ $ret -gt 1 ]] && exit 0
    [[ -z $mode ]] && exit 0
    mode=${mode##*$'\n'} # strip query line, keep selection
    case $mode in
    issue) state=ISSUE_PICK ;;
    'remote branch') state=REMOTE ;;
    pr) state=PR ;;
    esac
    ;;

  ISSUE_PICK)
    # 2>/dev/null: gh errors shown on stderr, don't capture into variable
    say 'fetching open issues'
    issues=$(run_timeout 15 gh issue list --state open --limit 50 2>/dev/null) || true
    issues=$(printf '%s\n' "$issues" | grep -E '^[0-9#]' || true)

    if [[ -z $issues ]]; then
      title=$(prompt 'Issue title (empty → cancel):')
      [[ -z $title ]] && {
        state=MENU
        continue
      }
      say 'creating issue'
      url=$(run_timeout 15 gh issue create --title "$title" --body "" 2>/dev/null) || true
      issue_n=$(_issue_n_from_url "$url")
      if [[ -z $issue_n ]]; then
        printf '\033[31mFailed to create issue\033[0m\n' >&2
        prompt_any_key
        state=MENU
        continue
      fi
      state=BRANCH
      continue
    fi

    choice=$(printf '%s\n' "$issues" |
      fzf_pick 'issue ❯' 'enter selects  ·  type new title + enter creates' \
        --preview='timeout 5 gh issue view {1} 2>/dev/null' \
        --preview-window='down:50%')
    ret=$?
    [[ $ret -gt 1 ]] && {
      state=MENU
      continue
    }
    [[ -z $choice ]] && {
      state=MENU
      continue
    }

    query=$(printf '%s\n' "$choice" | head -n1)
    selection=$(printf '%s\n' "$choice" | tail -n1)

    if [[ $ret -eq 1 || $query == "$selection" ]]; then
      say 'creating issue'
      url=$(run_timeout 15 gh issue create --title "$query" --body "" 2>/dev/null) || true
      issue_n=$(_issue_n_from_url "$url")
      if [[ -z $issue_n ]]; then
        printf '\033[31mFailed to create issue\033[0m\n' >&2
        prompt_any_key
        state=MENU
        continue
      fi
      state=BRANCH
      continue
    fi

    issue_n=$(printf '%s' "$selection" | awk '{print $1}' | sed 's/^#//')
    say 'checking linked branch'
    linked_branch=$(run_timeout 15 gh issue develop --list "$issue_n" 2>/dev/null | head -n1) || true

    if [[ -n $linked_branch && $linked_branch != 'There is no'* ]]; then
      pulldown "$linked_branch" "issue-$issue_n"
      # returns 1 on failure → fall back to MENU
      state=MENU
      continue
    else
      state=BRANCH
    fi
    ;;

  BRANCH)
    branchname=$(prompt 'Branch name (empty → cancel):')
    [[ -z $branchname ]] && {
      state=MENU
      continue
    }

    if git show-ref --quiet --verify "refs/remotes/origin/$branchname" 2>/dev/null; then
      state=BRANCH_CONFLICT
      continue
    fi

    say "creating remote branch: $branchname"
    if ! run_timeout 15 gh issue develop "$issue_n" --name "$branchname" 2>/dev/null; then
      printf '\033[31mgh issue develop failed — press any key\033[0m\n' >&2
      prompt_any_key
      state=MENU
      continue
    fi
    say 'fetching new branch from origin'
    git fetch origin "$branchname" 2>/dev/null || true
    pulldown "$branchname" "issue-$issue_n"
    # if pulldown fails (returns 1), loop back to MENU
    state=MENU
    continue
    ;;

  BRANCH_CONFLICT)
    printf '\033[33mBranch "%s" already exists on remote\033[0m\n' "$branchname" >&2
    action=$(printf 'rename branch name\npull it down anyway' |
      fzf_pick 'conflict ❯' 'enter picks action  ·  esc cancels')
    [[ -z $action ]] && {
      state=MENU
      continue
    }

    if [[ $action == 'rename branch name' ]]; then
      state=BRANCH
    else
      printf '\033[33mBranch already exists — gh does not support linking existing branches. Link manually if needed.\033[0m\n' >&2
      pulldown "$branchname" "issue-$issue_n"
      state=MENU
      continue
    fi
    ;;

  REMOTE)
    candidates=$(git branch -r 2>/dev/null | sed 's/^ *origin\///' | sort -u)
    if [[ -z $candidates ]]; then
      printf '\033[33mNo remote branches found\033[0m\n' >&2
      prompt_any_key
      state=MENU
      continue
    fi

    choice=$(printf '%s\n' "$candidates" |
      fzf_pick 'remote ❯' 'enter selects  ·  type new name + enter creates' \
        --preview='timeout 5 git log --oneline -10 origin/{1} 2>/dev/null' \
        --preview-window='down:50%')
    ret=$?
    [[ $ret -gt 1 ]] && {
      state=MENU
      continue
    }
    [[ -z $choice ]] && {
      state=MENU
      continue
    }

    query=$(printf '%s\n' "$choice" | head -n1)
    selection=$(printf '%s\n' "$choice" | tail -n1)

    if [[ $ret -eq 1 || $query == "$selection" ]]; then
      if ! git branch "$query" 2>/dev/null; then
        printf '\033[31mFailed to create local branch — press any key\033[0m\n' >&2
        prompt_any_key
        state=MENU
        continue
      fi
      if ! git push -u origin "$query" 2>/dev/null; then
        printf '\033[31mFailed to push branch — press any key\033[0m\n' >&2
        prompt_any_key
        state=MENU
        continue
      fi
      pulldown "$query" "$query"
      state=MENU
      continue
    else
      pulldown "$selection" "$selection"
      state=MENU
      continue
    fi
    ;;

  PR)
    # 2>/dev/null: gh errors shown on stderr, don't capture into variable
    say 'fetching open pull requests'
    prs=$(run_timeout 15 gh pr list --state open --limit 50 2>/dev/null) || true
    prs=$(printf '%s\n' "$prs" | grep -E '^[0-9#]' || true)

    if [[ -z $prs ]]; then
      printf '\033[33mNo open pull requests\033[0m\n' >&2
      prompt_any_key
      state=MENU
      continue
    fi

    choice=$(printf '%s\n' "$prs" |
      fzf_pick 'pr ❯' 'enter selects  ·  esc cancels' \
        --preview='timeout 5 gh pr view {1} 2>/dev/null' \
        --preview-window='down:50%')
    ret=$?
    [[ $ret -gt 1 ]] && {
      state=MENU
      continue
    }
    [[ -z $choice ]] && {
      state=MENU
      continue
    }

    query=$(printf '%s\n' "$choice" | head -n1)
    selection=$(printf '%s\n' "$choice" | tail -n1)

    if [[ $ret -eq 1 || $query == "$selection" ]]; then
      # typed something but no match → cancel (no "create PR" flow)
      state=MENU
      continue
    fi

    pr_number=$(printf '%s' "$selection" | awk '{print $1}' | sed 's/^#//')
    pulldown "pr:$pr_number" "pr-$pr_number"
    state=MENU
    continue
    ;;

  esac
done
