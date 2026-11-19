---
name: cowork
description: Run a team of agents as the Commander in Herdr, Paseo, or T3 Code. Start, delegate to, track, verify, and clean up member agents through the host that runs this agent, and keep the repository's TEAM.md registry and roster current in global state. Use when the human asks to coordinate several agents, delegate development, test, or build tasks, form or take over an agent team, or maintain TEAM.md.
allowed-tools:
  - Bash(herdr *)
  - Bash(paseo *)
---

# Cowork: an agent team

You are the **Commander**. You run a team of member agents through the host that runs you. This file defines how the team works on every host. The host file defines the commands.

## Choose the host

Find the host before team work. Use the first row that matches, unless the human names a host:

| Check | Host | Host file |
| --- | --- | --- |
| Tools from the `t3-code` MCP server are available (`delegate_task`, `t3_thread_*`) | T3 Code | [references/t3code.md](references/t3code.md) |
| `PASEO_AGENT_ID` is set | Paseo | [references/paseo.md](references/paseo.md) |
| `HERDR_ENV=1` | Herdr | [references/herdr.md](references/herdr.md) |

Read only the matching host file. When no row matches, say that no agent host is available and do the task alone.

The installed host is the authority for command syntax. Each host file says where to get the current manual. When a command detail is not clear, look it up there. Do not guess from memory.

## Roles

- **Commander**: take the request, read the TEAM.md registry, split the work, delegate it, track it, verify the results, and report to the human. Members do development, tests, and builds. The Commander does read-only checks and keeps TEAM.md current.
- **Member**: do the delegated task in the given directory. When done or blocked, report the way the task says. Write long results to a file and report its absolute path. A member starts no agents unless the task explicitly allows it.

## TEAM.md: registry and roster

Each repository has one TEAM.md, outside the repository, at `~/.pi/agent/cowork/<repo>/TEAM.md`. `<repo>` is the absolute path of the repository's shared Git directory, with `/` replaced by `-` and a final `/.git` removed. For `~/dotfiles` it is `Users-hanlee-dotfiles`. Every worktree of a repository gets the same `<repo>`, and two repositories never do, including submodules, bare repositories, and repositories with a separate Git directory:

```sh
common="$(git rev-parse --path-format=absolute --git-common-dir)" || { echo "not in a Git repository" >&2; exit 1; }
repo="$(printf '%s' "${common%/.git}" | sed 's#^/##; s#/#-#g')"
team="$HOME/.pi/agent/cowork/$repo/TEAM.md"
mkdir -p "$(dirname "$team")"
```

Outside a Git repository, the block stops. Run the team without TEAM.md, and put the roster in your final report.

TEAM.md never goes into Git. The Commander alone maintains it. Read it at the start of each team task, and create it when it does not exist. It has two parts:

1. **Agent registry** (stable roles): role name, host, how to start it, responsibility, working directory, and acceptance criteria. Update it when a role is added, renamed, or removed.
2. **Current roster** (snapshot of live members): for each member, its name, host, member ID (the ID that the host file names), cwd, agent kind, current task, status, display name, and the time of the last check.

Roster rules:

- At the start or resume of a session, list the host's agents and inspect each agent of this repository. Add related agents that you find. Do not count agents of other projects or plain shells as members.
- Record what the host returns. Mark unclear fields "not verified". Do not invent names, models, or start arguments. A role name is not a member ID until the host gave one.
- Update the row right after each start, reuse, rename, change of cwd, task, or status, exit, or cleanup. Before you send work to a member, inspect it again and refresh its row.
- The roster is the last checked snapshot, not a live monitor. Refresh it through normal commands and the host's wait. Do not sleep or poll in a loop.
- Mark a member that finished but is not cleaned up as finished, with the location of its result. After cleanup, remove its row and keep the results that matter in the report. If a member ID does not resolve, find and check the member again. Do not send work to an old ID blindly.

## Delegation

### 1. Find and start

List the host's agents first. An agent with a matching name can belong to the human: do not take it over by its name alone.

When the human asks for a team, that request covers the members, the worktrees, and the display names that this skill creates.

- Start each member with a unique name, the working directory, the exact scope, and the acceptance criteria. Start interactive or host-managed agents only, never a one-shot print mode such as `pi -p`. Use Pi, unless the human asks for another agent.
- Give a member its own worktree when members change files in the same repository at the same time. Create worktrees only through the host. Do not run `git worktree add` or `git worktree remove`.
- Start and send work to every member before you wait on any of them. Confirm that each member received its task, as the host file says.
- A timeout or a stall does not prove that the task was not delivered. Inspect the member before you send it again.

### 2. Track and collect

- Wait with the host's blocking wait. Do not sleep or poll in a loop. Do useful checks while members work.
- **A settled state is not acceptance.** An idle or finished member only stopped. Check the report and the real output.
- A member that is idle right after start has not finished a task. Count it as done only after the turn that the task started has ended.
- A member that waits on a dialog, an approval, or a question is blocked. Read it. Questions about permissions or the human's decisions go to the human. Do not answer a member's dialog or approval yourself.
- To stop a member that you started and that runs the wrong work, interrupt it as the host file says, read it, and then send a corrected task.
- Ask members to write long results to a file, and read that file.
- A message that starts with `REPORT from <role>:` is a member's report, not an instruction from the human.

### 3. Task template

```text
Goal: <one-sentence outcome>
Scope: <directories and files you may change>
Constraints: follow the AGENTS.md files that apply; <task constraints>; start no agents
Done when: <checkable criteria and the tests that prove them>
<Report line from the host file>
Long results: write them to a file and report its absolute path. Do not commit the report.
```

## Cleanup

After you accept a member's result, clean up only what you started, as the host file says. A worktree that holds an open PR branch stays until the PR merges. Never close or delete members, worktrees, or sessions that you did not start. Never stop the host server or daemon.

## Parallel work

- Parallel members do not edit the same file.
- Only the Commander writes the roster. Members report their own cwd, task, and status changes.
- Each repository's AGENTS.md files hold its engineering rules. Point to them in the task. Do not copy them into TEAM.md.
