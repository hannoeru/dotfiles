# Worktrunk

A [herdr](https://herdr.dev) plugin that drives
[worktrunk](https://github.com/max-sixty/worktrunk) (`wt`) from the workspace
context menu: switch, create, remove, and merge git worktrees, then pull remote
branches, pull requests, and issues into a herdr workspace. Pick (or type) a
branch in an fzf picker; worktrunk's lifecycle hooks run along the way.

Merged from two MIT-licensed plugins:

- [devashish2203/herdr-worktrunk](https://github.com/devashish2203/herdr-worktrunk) — switch/create/remove/merge with native worktree workspaces
- [ditwrd/herdr-remote-worktrunk](https://github.com/ditwrd/herdr-remote-worktrunk) — remote branch, PR, and issue pulls via `gh`

## Actions

- **Worktree: switch / create from default branch** (`open`) — fzf over existing worktrees and local branches. `Enter` on a match switches to it; type a new name to create it from worktrunk's default base.
- **Worktree: switch / create from current branch** (`open-current`) — same, but new names branch from the current worktree.
- **Worktree: switch / create from local or remote branches** (`open-with-remotes`) — includes remote-tracking branches.
- **Worktree: pull branch / PR / issue** (`pull`) — a menu of issue / remote branch / PR, using `gh` and `wt switch pr:N`.
- **Worktree: remove** (`remove`) — fzf over removable worktrees; `wt remove` prompts for confirmation.
- **Worktree: merge into the target branch** (`merge`) — `wt merge` then remove.
- **Worktree: merge into the target branch, keeping every commit** (`merge-no-squash`) — same with `--no-squash`.

## Requirements

- herdr ≥ 0.7.0
- worktrunk ≥ 0.60.0 — `wt` on `PATH`
- fzf, jq, bash
- gh (only for **pull branch / PR / issue**)
- `timeout`/`gtimeout` (coreutils) — optional: caps `gh`/`wt` in the pull flows when available

## Install

The plugin ships with these dotfiles as `home/.config/herdr/plugins/worktrunk`
and is linked to `~/.config/herdr/plugins/worktrunk`. Register it with herdr
once per machine:

```bash
herdr plugin link ~/.config/herdr/plugins/worktrunk
```

Then reload the session/config so the workspace context menu and keybindings
pick it up. herdr caches the manifest at link time, so after editing
`herdr-plugin.toml` relink:

```bash
herdr plugin unlink worktrunk && herdr plugin link ~/.config/herdr/plugins/worktrunk
```

Edits to the shell scripts are picked up on the next run.

## Configuration

Plugin config lives in the directory printed by
`herdr plugin config-dir worktrunk` (a `config.toml` there):

```toml
# open_mode = "workspace"   # default: register a native linked-worktree workspace
# open_mode = "tab"         # open a tab and type `wt switch` into its shell
# show_remote_branches = true
# picker_placement = "popup"  # default: "split"
# popup_width = "70%"
# popup_height = 24
# merge_flags = "--no-squash --no-rebase"
```

## Keybindings

```toml
[[keys.command]]
key = "prefix+shift+g"
type = "plugin_action"
command = "worktrunk.open"
description = "Worktree: switch / create"

[[keys.command]]
key = "prefix+shift+c"
type = "plugin_action"
command = "worktrunk.open-current"
description = "Worktree: create from current"

[[keys.command]]
key = "prefix+shift+d"
type = "plugin_action"
command = "worktrunk.remove"
description = "Worktree: remove"

[[keys.command]]
key = "prefix+shift+m"
type = "plugin_action"
command = "worktrunk.merge"
description = "Worktree: merge"

[[keys.command]]
key = "prefix+shift+p"
type = "plugin_action"
command = "worktrunk.pull"
description = "Worktree: pull branch / PR / issue"
```

`herdr plugin action list` shows the full qualified ids.

## License

[MIT](LICENSE.md) — merged from the upstream plugins; both upstream copyrights
are retained in the license file.
