- Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.
- Code, comments, docs, and tests describe the present; use Git history for historical context.
- Always talk in ASD-STE100 Simplified Technical English. Always read CONTEXT.md files, and use their ubiquitous language.
- Always write commit messages that follow the Conventional Commits specification.
- Write review findings as short, direct comments. Explain the defect, when it occurs, and why it matters.
- Write replies to review comments as short, factual responses. State the change made or the reason for disagreement.
- Default to no code comments. Add one only to explain a constraint, workaround, or bug link that the code cannot express.
- Never use fixed delays or elapsed time to infer command completion or readiness. Wait for the process to exit or poll an explicit completion/readiness condition; use timeouts only as safety limits for stuck commands.

## Herdr agent defaults

When running inside Herdr (`HERDR_ENV=1`):

- Use the installed Herdr skill for agent orchestration.
- Always use `pi` as the default agent kind.
- Start all helper agents with `herdr agent start <name> --kind pi --pane <pane-id>`.
- Never select another agent kind unless I explicitly request it.
- Create the target pane first and use the pane ID returned by Herdr.
- Do not control Herdr when `HERDR_ENV=1` is not set.

