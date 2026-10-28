- Do not preserve backward compatibility. Remove obsolete paths instead of adding compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components modular and concerns clearly separated.
- Extract a helper only for reuse, a complex boundary, or a clear name that improves the caller.
- Validate unknown values once at the boundary that owns them. Do not repeat checks for values guaranteed by schemas, constructors, or types.
- Before adding complexity for a speculative edge case, explain the concrete failure mode, likelihood, and complexity cost. Get user approval first.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Do not reimplement common functionality without a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Do not assume a library lacks a capability without checking its documentation and types.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.
- Code, comments, docs, and tests describe the present; use Git history for historical context.
- When repository documentation and existing code disagree, follow the conventions in the existing code. Report each inconsistency in the final reply.
- Always talk in ASD-STE100 Simplified Technical English. Always read CONTEXT.md files, and use their ubiquitous language.
- Use short, descriptive branch names.
- Always write commit messages and PR titles that follow the Conventional Commits specification.
- Keep the PR body current. After you push more work to an open PR, rewrite the body with `gh pr edit` in the same turn. The work is done when every summary item, note, and test result in the body matches the final diff.
- Write review findings as short, direct comments. Explain the defect, when it occurs, and why it matters.
- Write replies to review comments as short, factual responses. State the change made or the reason for disagreement.
- Default to no code comments. Add one only to explain a constraint, workaround, or bug link that the code cannot express.
- Test the real implementation. Do not duplicate its logic in tests.
- Run the documented checks that apply to the change. If local checkers disagree, use the checker required by CI as the authority.
- Never use fixed delays or elapsed time to infer command completion or readiness. Wait for the process to exit or poll an explicit completion/readiness condition; use timeouts only as safety limits for stuck commands.

## Global task defaults

- For every task, read and follow the `/poteto-mode` skill if installed, even when hidden from model invocation. If it is not installed, continue without it.
- When `HERDR_ENV` is not `1` or the `/herdr` skill is not installed, continue the task in the current directory without Herdr. The Herdr instructions below apply only when `HERDR_ENV=1` and the skill is installed.
- Read and follow the `/herdr` skill.
- Before task work, inspect Herdr worktrees. Reuse the matching task branch and worktree, or create one with `herdr worktree create`.
- Use the absolute checkout path returned by Herdr for all task commands and edits. If the current session cwd differs, launch Pi in that worktree pane and continue the task there.
- Same-task helpers share the task worktree. Distinct tasks use separate worktrees.
- Create the target pane first, with its cwd set to the task worktree. Use the pane ID returned by Herdr in `herdr agent start <name> --kind pi --pane <pane-id>`.
- Never select another agent kind unless I explicitly request it.

