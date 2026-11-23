# Herdr host

A member is an interactive agent in a Herdr pane. The member ID is the agent name that `herdr agent start` gave, or its pane ID.

## Manual

- The system prompt holds the Herdr skill. If it does not, run `herdr --skill`.
- Run `herdr <group>` (for example `herdr agent`) for the commands of a group, and `herdr <group> <command> --help` for the exact options.
- Read your own pane with `herdr pane current --current`.

## Codemode tools

Pi in Herdr has the `herdr-codemode` extension. When codemode has `tools.herdr_search`, prefer one codemode script for a sequence of steps, such as start, send, confirm, and name. The rules in this file stay the same. Only the calls change. Use the CLI when the tools are missing.

| Step | Tool | CLI |
| --- | --- | --- |
| Find IDs | `herdr_session_snapshot`, `herdr_panes_current` | `herdr pane current --current` |
| List and inspect | `herdr_agents_list`, `herdr_agents_get` | `herdr agent list`, `herdr agent get` |
| Same checkout | `herdr_panes_split` | `herdr pane split` |
| Separate checkout | `herdr_worktrees_create` | `herdr worktree create` |
| Start | `herdr_agents_start({ name, kind: "pi", paneId })` | `herdr agent start` |
| Send work | `herdr_agents_prompt({ name, text })` | `herdr agent prompt` |
| Confirm or read | `herdr_agents_read({ name, source: "visible" })` | `herdr agent read` |
| Wait | `herdr_agents_wait({ name, until: ["done", "blocked"], timeoutMs })` | `herdr agent wait --until done --until blocked` |
| Display name | `herdr_tabs_rename({ tabId, label })` | `herdr tab rename` |
| Slow command | `herdr_panes_sendText`, then `herdr_panes_waitForOutput` | `herdr pane run`, then `herdr pane wait-output` |
| Cleanup | `herdr_panes_close`, `herdr_worktrees_remove` | `herdr pane close`, `herdr worktree remove` |

- Get each signature with `describeTool(name)` in the same script. Return only the IDs and text that you need.
- Waits need `timeoutMs`. `{ timedOut: true }` is not a failure: read the member before you wait again.
- A failure starts with its SDK error tag. `HerdrRequestTimeout` and the `timeout` or `agent_prompt_stalled` codes of `herdr_agents_prompt` do not prove that the task was not delivered. Read the member before you send it again.
- Do not use `herdr_agents_sendKeys` or `herdr_panes_sendInput` to answer a dialog. Do not call `herdr_server_stop` or `herdr_server_liveHandoff`.

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
