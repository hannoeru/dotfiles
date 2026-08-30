# Default branch of the origin remote, used by abbreviations.
git_default_branch() {
  local ref
  ref="$(git symbolic-ref --short --quiet refs/remotes/origin/HEAD 2>/dev/null)" && {
    printf '%s\n' "${ref#origin/}"
    return
  }
  git config --get init.defaultBranch 2>/dev/null || printf 'main\n'
}
