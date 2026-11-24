# Paseo host

A member is an agent that the Paseo daemon runs. The member ID is its agent ID. When a Paseo agent creates an agent, the new agent is its subagent in the same workspace, unless you place it in another workspace.

## Choose the route

- **Tools route**: use it when you have the Paseo agent tools (`create_agent`, `send_agent_prompt`, `get_agent_status`). Paseo then sends you finish, error, and permission notifications for each member.
- **CLI route**: use it when you do not have the tools, or when the member runs on another host. The CLI sends no notifications, so you wait and check for permission requests yourself.

A running session keeps the tools it got at launch. When the tools are missing, do not change the Paseo settings. Use the CLI route.

## Manual

- Tools route: the tool descriptions are the authority for inputs and results.
- CLI route: run `paseo --help` for the command list, and `paseo <command> --help` for the exact options. Use `--json` on every command whose output you read, and read IDs from that output.
- Your own agent ID is in `PASEO_AGENT_ID`.

## Roster fields

List agents with `list_agents` or `paseo ls --json`. Inspect each agent of this repository with `get_agent_status` or `paseo inspect <id> --json`. The display name is the agent name (CLI: the title).

## Start

Write a long task to a file, and start the member with the prompt "Read <path> and do that task exactly."

Tools route:

- `create_agent` with `initialPrompt` and a `provider/model` pair. `create_agent` takes no profile. Use the Pi provider, unless the human asks for another one. Get its models with `paseo provider models pi`.
- For a separate checkout, create the worktree with `wt`, as `SKILL.md` says. Register its path as a local workspace with `paseo workspace create --isolation local --path <worktree path> --title <role> --json`, and pass that workspace ID as `workspaceId` to `create_agent`.
- Name the member after its role with `update_agent`.
- Do not set `background: true` or `notifyOnFinish: false`. Without the notifications, you do not see when a member finishes or is blocked.

CLI route:

```sh
# Same checkout.
paseo run --no-wait --json --provider pi --title <role> --cwd "$PWD" "<first task>"
# Separate checkout: a wt worktree, registered as a local workspace.
paseo workspace create --isolation local --path <worktree path> --title <role> --json
paseo run --no-wait --json --provider pi --title <role> --workspace <workspace-id> "<first task>"
```

- Change `--provider` only when the human asks for another agent. Run `paseo provider ls` to see the providers that this host has enabled.
- `paseo send <id> --prompt-file <path>` sends a file as a follow-up.
- Do not use Paseo's own worktrees (`--new-workspace worktree`, `--isolation worktree`). `wt` owns the worktrees.

On both routes, confirm delivery in the member's activity (`get_agent_activity` or `paseo logs <id> --tail 20`): the task text must be there.

## Report line

```text
When done or blocked: end your turn with a message that starts "REPORT from <role>:", with the result, changed files, check results, or the block.
```

The member does not send its report to the Commander. The report is the member's last message.

## Wait, read, and stop

Tools route:

- `create_agent` and `send_agent_prompt` return without waiting. Do other work, or end your turn. The finish, error, or permission notification wakes you. Do not poll `get_agent_status` in a loop.
- Read the result with `get_agent_activity` and `get_agent_status`.
- A permission notification means the member is blocked. Read it with `list_pending_permissions`, and give it to the human. Do not call `respond_to_permission` yourself.
- Send a follow-up with `send_agent_prompt`. To interrupt a member that you started, call `cancel_agent`, then read its activity.

CLI route:

- Wait with `paseo wait <id> --timeout <seconds> --json`. When the wait times out, inspect the member before you wait again.
- Read the result with `paseo logs <id>` and `paseo inspect <id> --json`.
- A member that waits on a permission request is blocked. After each wait, and before you wait again, run `paseo permit ls --json`. Give each request of a member to the human. Do not run `paseo permit allow` or `deny` yourself.
- Send a follow-up with `paseo send <id> "<message>"`. To interrupt a member that you started, run `paseo stop <id>`, then read its log.

## Slow commands and other machines

- Run slow commands in a member, or in a workspace terminal (`paseo terminal`), not in the Commander's own turn.
- For another machine, use the CLI route. Put `--host <host>` on every command, and find IDs on that host. `--cwd` is a path on that host.

## Cleanup

Archive a finished member with `archive_agent` or `paseo archive <id>`. Use `kill_agent` or `paseo delete <id>` only for a member that you started, after you saved the results that matter. Archive a workspace that you created with `archive_workspace` or `paseo workspace archive <workspace-id>`, which also archives the agents in it. Then remove its worktree with `wt`, as `SKILL.md` says. Never stop or restart the daemon.
