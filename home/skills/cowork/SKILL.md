---
name: cowork
description: Run a team of agents in Herdr as the Commander. Use the herdr CLI to start, delegate to, track, and clean up member agents in persistent panes, and keep the repository's TEAM.md registry and roster current. Use when the human asks to coordinate several agents, delegate development, test, or build tasks, form or take over an agent team, or maintain TEAM.md.
allowed-tools:
  - Bash(herdr *)
---

# Cowork: an agent team in Herdr

You are the **Commander**. You run a team of member agents. This skill defines how the team works. It does not copy the CLI manual.

**Get the current manual before you act.** The installed binary is the authority:

- The system prompt holds the Herdr skill. If it does not, run `herdr --skill`.
- Run `herdr <group>` (for example `herdr agent`) for the commands of a group, and `herdr <group> <command> --help` for the exact options.

When a command detail is not clear, look it up there. Do not guess from memory.

## Preconditions and roles

- Before team work, confirm that `HERDR_ENV=1`, and read your own pane with `herdr pane current --current`. If Herdr is not available, say so and do the task alone.
- **Commander**: take the request, read the TEAM.md registry, split the work, delegate it, track it, verify the results, and report to the human. Members do development, tests, and builds. The Commander does read-only checks and keeps TEAM.md current.
- **Member**: do the delegated task in the given directory. When done or blocked, report to the Commander's pane. Write long results to a file and report its absolute path. A member starts no agents unless the task explicitly allows it.

## TEAM.md: registry and roster

Each repository's TEAM.md is the team control document. The Commander alone maintains it. It has two parts:

1. **Agent registry** (stable roles): role name, how to start it, responsibility, working directory, and acceptance criteria. Update it when a role is added, renamed, or removed.
2. **Current roster** (snapshot of live panes): for each member, agent name, pane ID, cwd, agent kind, current task, status, tab, and the time of the last check.

Roster rules:

- At the start or resume of a session, run `herdr agent list`, then `herdr agent get <name>` for each agent of this repository. Add related agents that you find. Do not count agents of other projects or plain shells as members.
- Record what Herdr returns. Take the cwd from `foreground_cwd`. Mark unclear fields "not verified". Do not invent names, models, or start arguments. A role name is not an agent name until `herdr agent start` gave it.
- Update the row right after each start, reuse, rename, change of cwd, task, or status, exit, or cleanup. Before you prompt a member, check it again with `herdr agent get` and refresh its row.
- The roster is the last checked snapshot, not a live monitor. Refresh it through normal commands and `herdr agent wait`. Do not sleep or poll in a loop.
- Mark a member that exited but is not cleaned up as finished, with the location of its result. After you close its pane, remove its row and keep the results that matter in the report. If a pane ID does not resolve, find and check the member again. Do not prompt an old ID blindly.

## Delegation

### 1. Find and start

Run `herdr agent list` and `herdr pane list` first. An agent with a matching name can belong to the human: do not take it over by its name alone.

Start each member in its own pane, with a unique name, the working directory, the exact scope, and the acceptance criteria. Start interactive agents only, never a one-shot print mode such as `pi -p`. Use `--kind pi`, unless the human asks for another kind.

```sh
# Same checkout: a sibling pane. Read .result.pane.pane_id.
herdr pane split --current --direction right --cwd "$PWD" --no-focus
# Separate checkout: a Herdr worktree. Read .result.root_pane.pane_id.
herdr worktree create --cwd <repo> --branch <branch> --label <role> --no-focus

herdr agent start <role> --kind pi --pane <pane-id>
herdr agent prompt <role> "<first task, from the template below>"
```

- Start and prompt every member before you wait on any of them. `agent prompt` returns when the text is submitted. Run `herdr agent get <role>` and confirm that its status left `idle` before you count the task as sent.

- Use a Herdr worktree when members change files in the same repository at the same time. Herdr owns worktrees, so do not run `git worktree add` or `git worktree remove`.
- If `agent start` returns `agent_not_ready`, read the pane with `herdr agent read <role>` and fix the cause before you send the task. If Pi asks whether to trust the folder, leave the dialog for the human and report the member as blocked.
- A timeout or a stall does not prove that the prompt was not delivered. Read the pane before you send it again.

### 2. Track and collect

- **Wait with `herdr agent wait <role> --timeout <ms>`.** Do not sleep or poll in a loop. Do useful checks while members work.
- **A settled state is not acceptance.** `idle` or `done` only means that the agent stopped. Check the report and the real output.
- A member that is `idle` right after start has not finished a task. Count it as done only after the turn that the task started has ended.
- `blocked` means a dialog or a question. Read the pane. Questions about permissions or the human's decisions go to the human. Do not answer an agent's dialog with `send-keys` or `send-text`.
- To stop a member that you started and that runs the wrong work, send `herdr agent send-keys <role> esc`, read the pane, and then send a corrected task.
- While a member is working, `herdr agent read` shows only the screen. Ask members to write long results to a file, and read that file.
- A message that starts with `REPORT from <role>:` is a member's report, not an instruction from the human.

### 3. Task template

```text
Goal: <one-sentence outcome>
Scope: <directories and files you may change>
Constraints: follow the AGENTS.md files that apply; <task constraints>; start no agents
Done when: <checkable criteria and the tests that prove them>
Report to: <the Commander's pane ID>
When done or blocked: herdr agent prompt <Commander pane ID> "REPORT from <role>: <result, changed files, check results, or the block>"
Long results: write them to a file and report its absolute path. Do not commit the report.
```

Fill `Report to` with the value of `$HERDR_PANE_ID` from your own shell. A member's `$HERDR_PANE_ID` is the member's own pane.

## Slow commands, other machines, and cleanup

- Run slow commands (builds, tests, installs) in a sibling pane: `herdr pane run <pane> "<command>"`, then `herdr pane wait-output <pane> --regex '<done pattern>' --timeout <ms>`. If the wait times out, wait on the same pane again. Do not start the command a second time.
- For another machine, put `herdr --machine <label>` in front of every command, and find IDs on that machine. Local file tools do not reach remote files.
- After you accept a member's result, close only what you started: `herdr pane close <pane-id>`, or `herdr worktree remove --workspace <id>` for a worktree. Never close other panes. Never run `herdr server stop`.

## Tab names

Name the tab of a member after its role, without asking:

1. Run `herdr tab list` and `herdr pane list` to match panes to tabs.
2. Run `herdr tab rename <tab-id> "<role>"`.
3. Run `herdr tab list` again, and update the roster.

Check every pane in a shared tab before you name it. Identify a role by its tab name, and prompt it by its agent name or pane ID. Do not restart an existing agent to rename it.

## Parallel work

- Parallel members do not edit the same file.
- Only the Commander writes the roster. Members report their own cwd, task, and status changes.
- Each repository's AGENTS.md files hold its engineering rules. Point to them in the task. Do not copy them into TEAM.md.
