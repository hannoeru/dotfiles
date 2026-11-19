# Paseo host

A member is an agent that the Paseo daemon runs. The member ID is the agent ID that `paseo run` returns. When a Paseo agent runs `paseo run`, the new agent is its subagent in the same workspace, and the Commander gets a notification when the member finishes.

## Manual

- Run `paseo --help` for the command list, and `paseo <command> --help` for the exact options.
- Use `--json` on every command whose output you read, and read IDs from that output.
- Your own agent ID is in `PASEO_AGENT_ID`.

## Roster fields

Run `paseo ls --json`, then `paseo inspect <id> --json` for each agent of this repository. The display name is the agent title.

## Start

```sh
# Same checkout.
paseo run --no-wait --json --provider pi --title <role> --cwd "$PWD" "<first task>"
# Separate checkout: a Paseo worktree.
paseo run --no-wait --json --provider pi --title <role> \
  --new-workspace worktree --worktree-mode branch-off --new-branch <branch> --base <ref> \
  "<first task>"
```

- Change `--provider` only when the human asks for another agent. Run `paseo provider ls` to see the providers that this host has enabled.
- Put a long task in a file and send it with `paseo send <id> --prompt-file <path>`.
- Confirm delivery with `paseo logs <id> --tail 20`: the task text must be in the log.

## Report line

```text
When done or blocked: end your turn with a message that starts "REPORT from <role>:", with the result, changed files, check results, or the block.
```

Paseo notifies the Commander when the member finishes, so the member does not send its report to the Commander.

## Wait, read, and stop

- Wait with `paseo wait <id> --timeout <seconds> --json`. When the wait times out, inspect the member before you wait again.
- Read the result with `paseo logs <id>` and `paseo inspect <id> --json`.
- A member that waits on a permission request is blocked. List requests with `paseo permit ls`, and give each one to the human. Do not run `paseo permit allow` or `deny` yourself.
- Send a follow-up with `paseo send <id> "<message>"`. To interrupt a member that you started, run `paseo stop <id>`, then read its log.

## Slow commands and other machines

- Run slow commands in a member, or in a workspace terminal (`paseo terminal`), not in the Commander's own turn.
- For another machine, put `--host <host>` on every command, and find IDs on that host. `--cwd` is a path on that host.

## Cleanup

Archive a finished member with `paseo archive <id>`. Use `paseo delete <id>` only for a member that you started, after you saved the results that matter. Remove a worktree workspace that you created with `paseo workspace archive <workspace-id>`, which also archives everything it owns. Never stop or restart the daemon.
