# Herdr app host

The Herdr app is a desktop window. Its terminals and agents run in herdr-core, and the team uses its CLI, `hc`, not `herdr`. A member is an interactive agent in an `hc` terminal. The member ID is the terminal name that you give with `--name`, or its address (`t7`, or `machine/t7` on another machine).

## Manual

- Run `hc --skill` for the current manual, and `hc <command> --help` for the exact options. `herdr-app --skill` covers the window, which the team does not need to change.
- Your own address is in `HC_TERMINAL_ID`. It is not a Herdr pane ID.
- Terminals that you start are your children. They end when your own program ends, unless you start them with `--outlive-parent`. Tell the human this before you end a session with members still at work.

## Roster fields

Run `hc ls`, then `hc get <t>` for each terminal of this repository. Record its address, name, cwd, agent, state, and status. `hc ls` also shows the human's other work: those terminals are not members.

## Start

```sh
hc run --bg --name <role> --cwd <dir> pi "Read <task file> and do that task exactly."
```

- Always use `--bg`. Put the first task in `run`, because a message sent to an agent that is still starting can be lost. Change `pi` only when the human asks for another agent.
- `hc templates` lists ready-made roles. Use one that fits: `hc run --bg --name <role> --cwd <dir> <template> "<task>"`. For a template launch, check `first_message.sent` in the result. When it is false, the task was not sent: read the terminal, fix the cause, then send the task.
- Confirm delivery with `hc read <role> --lines 40`: the task text must be there.
- **Worktrees.** For a separate checkout, create the worktree with `wt`, as `SKILL.md` says, and start the member with `--cwd` set to its path.
- Do not add `herdr.space` or `herdr.tab` labels. Members stay out of the window unless the human asks to see them.

## Report line

```text
When done or blocked: hc send <Commander address> "REPORT from <role>: <result, changed files, check results, or the block>"
```

Fill the address with the value of `$HC_TERMINAL_ID` from your own shell. Reports arrive tagged, for example `<hc from="t7 review">…</hc>`. hc also notifies you when a member cannot report, because it is blocked, has an error, or exited.

## Wait, read, and stop

- Wait with `hc wait --children any` (the next member news) or `hc wait --children all`. Use `hc wait <t>` for one member.
- A wait can return `idle` before a new member has started its turn. When a member is idle and its report is not in `hc read`, wait again.
- `reason: timeout` (180 seconds by default) is a check-in, not a failure: wait again. `reason: message` means a report arrives as your next input. It is not output to fetch with `hc read`.
- `blocked` means a permission or a question. Read the screen with `hc read <t>`, and give it to the human. Do not answer it with `hc keys`, and do not use `hc send --force`.
- Read a member with `hc read <t> --lines 100`. While it is `working`, `blocked`, or in `error`, a read returns only the screen.
- Send a follow-up with `hc send <t> "<message>"`. To stop the current turn of a member that you started, run `hc interrupt <t>`, then read it.

## Slow commands and other machines

- Run slow commands in an `hc` terminal, not in your own shell tool: `hc run --bg --rm --no-notify --name build <command>`, then `hc wait build`. If `hc run` returns exit 124, the program still runs at the returned address. Wait on it. Do not start it again.
- For another machine, add `--on <machine>` to `run`, and use the full `machine/t7` address. Use `hc exec --on` and `hc file … --on` for remote commands and files. Your local file tools do not reach that machine.

## Cleanup

End a member with `hc kill <t>`, then `hc rm <t>`. After the member ends, remove its worktree with `wt`, as `SKILL.md` says. Never run `hc server stop` or restart the core.
