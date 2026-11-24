# T3 Code host

A member is a T3 thread. T3 Code gives its agents the `t3-code` MCP server, and the team uses those tools, not a shell command. The member ID is the child thread ID (`childThreadId`) of a delegated task, or the thread ID of a launched thread.

## Manual

- The tool descriptions of the `t3-code` server are the authority for inputs and results.
- Run `orchestrator_capabilities` first. It lists the providers, models, and modes that can run a member.

## Roster fields

Run `t3_thread_list` for this project, and `t3_thread_read` or `task_status` for each member. The display name is the thread title.

## Start

- **Delegated member in your checkout**: `delegate_task` with the task prompt and `mode: "async"`. Do not set `isolation: "worktree"`, because `wt` owns the worktrees.
- **Member in its own checkout**: create the worktree with `wt`, as `SKILL.md` says. Then call `t3_thread_launch` with a `message` and `workspaceStrategy` `existing_worktree` with `worktreePath` set to its path.
- Use the Pi provider, unless the human asks for another one. Give each call a `clientRequestId` that stays the same when you retry the call. A launch has no retry key, so list the threads before you launch again.
- The member gets only the task prompt, not your conversation. Put all the context in the task.
- Confirm delivery with `task_status`, or with `t3_thread_read` on the member thread.

## Report line

```text
When done or blocked: end your turn with a message that starts "REPORT from <role>:", with the result, changed files, check results, or the block.
```

The result of the member's last turn is the task result, and its completion wakes the Commander. The member does not send its report to the Commander.

## Wait, read, and stop

- Wait with `delegate_task` in `mode: "wait"` or with `t3_thread_wait`. A timeout does not cancel the member.
- When a result includes `next`, completion wakes you. Do not wait on that task again. Continue other work, or end the turn.
- `hasPendingQuestion` or `pendingApproval` means the member is blocked. Give the question to the human. Do not answer an approval yourself.
- Send a follow-up with `t3_thread_send`. Interrupt a member that you started with `t3_thread_interrupt`, and cancel a delegated task with `task_cancel`.

## Display name

Rename a member thread after its role with `t3_thread_update`, action `rename`.

## Cleanup

Cancel a running task that you started and do not need with `task_cancel`. Interrupt a launched thread with `t3_thread_interrupt` before you remove its worktree with `wt`, as `SKILL.md` says. T3 Code keeps finished threads. Leave them for the human unless the human asks you to remove them.
