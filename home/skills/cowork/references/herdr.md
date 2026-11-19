# Herdr host

A member is an interactive agent in a Herdr pane. The member ID is the agent name that `herdr agent start` gave, or its pane ID.

## Manual

- The system prompt holds the Herdr skill. If it does not, run `herdr --skill`.
- Run `herdr <group>` (for example `herdr agent`) for the commands of a group, and `herdr <group> <command> --help` for the exact options.
- Read your own pane with `herdr pane current --current`.

## Roster fields

Run `herdr agent list`, then `herdr agent get <name>` for each agent of this repository. Take the cwd from `foreground_cwd`. The display name is the tab name.

## Start

```sh
# Same checkout: a sibling pane. Read .result.pane.pane_id.
herdr pane split --current --direction right --cwd "$PWD" --no-focus
# Separate checkout: a Herdr worktree. Read .result.root_pane.pane_id.
herdr worktree create --cwd <main-checkout> --branch <branch> --label <role> --no-focus

herdr agent start <role> --kind pi --pane <pane-id>
herdr agent prompt <role> "<first task>"
```

- Run `herdr pane list` before you start. Change `--kind` only when the human asks for another agent.
- `agent prompt` returns when the text is submitted, and Herdr can still report `idle` while the member works. Run `herdr agent read <role> --source visible` and confirm that the task text is on the screen before you count it as sent.
- If `agent start` returns `agent_not_ready`, read the pane with `herdr agent read <role>` and fix the cause before you send the task. If Pi asks whether to trust the folder, leave the dialog for the human and report the member as blocked.

## Report line

```text
Report to: <the Commander's pane ID>
When done or blocked: herdr agent prompt <Commander pane ID> "REPORT from <role>: <result, changed files, check results, or the block>"
```

Fill the pane ID with the value of `$HERDR_PANE_ID` from your own shell. A member's `$HERDR_PANE_ID` is the member's own pane.

## Wait, read, and stop

- Wait with `herdr agent wait <role> --until done --until blocked --timeout <ms>`. A plain `agent wait` can return at once on the `idle` state of a member that has just started.
- `blocked` means a dialog or a question. Read the pane with `herdr agent read`. Do not answer it with `send-keys` or `send-text`.
- While a member works, `herdr agent read` shows only the screen.
- To interrupt a member that you started, send `herdr agent send-keys <role> esc`, then read the pane.

## Display name

Name the tab of a member after its role, without asking:

1. Run `herdr tab list` and `herdr pane list` to match panes to tabs.
2. Run `herdr tab rename <tab-id> "<role>"`.
3. Run `herdr tab list` again, and update the roster.

Check every pane in a shared tab before you name it. Prompt a role by its agent name or pane ID. Do not restart an existing agent to rename it.

## Slow commands and other machines

- Run slow commands (builds, tests, installs) in a sibling pane: `herdr pane run <pane> "<command>"`, then `herdr pane wait-output <pane> --regex '<done pattern>' --timeout <ms>`. If the wait times out, wait on the same pane again. Do not start the command a second time.
- For another machine, put `herdr --machine <label>` in front of every command, and find IDs on that machine. Local file tools do not reach remote files.

## Cleanup

Close a pane with `herdr pane close <pane-id>`, or a worktree with `herdr worktree remove --workspace <id>`, which also stops its agents. Never run `herdr server stop`.
