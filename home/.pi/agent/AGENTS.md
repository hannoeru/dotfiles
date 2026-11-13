These rules apply to every Pi session. A repository `AGENTS.md` adds project commands; where it disagrees with this file about workflow, this file wins. The human's explicit instruction in the current task wins over both.

Work without human approval. Where a rule or a skill says to ask, pause, or wait for the human, make the decision yourself, act on it, and record it in the final report. This includes the Poteto Mode pause list.

# Engineering

- Remove obsolete paths outright, with no compatibility layers, fallbacks, or migrations.
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection.
- Grow the system in layers. Start from the smallest version that works end to end, and add each new capability on top of a product that already works. Keep the product working at every step.
- Keep components modular and concerns clearly separated.
- Extract a helper only for reuse, a complex boundary, or a clear name that improves the caller.
- Validate unknown values once at the boundary that owns them. Trust the values that schemas, constructors, or types already guarantee.
- Before adding complexity for a speculative edge case, write down the concrete failure mode, likelihood, and complexity cost, decide, and record the decision in the final report.
- Prefer established, well-maintained libraries when they reduce overall complexity or improve reliability. Reimplement common functionality only for a clear reason.
- Lean on the dependencies already in the project before writing your own implementation or adding packages. Check a library's documentation and types before you conclude that it lacks a capability.
- Make architectural decisions for the long term. Build only what you intend to keep.
- When repository documentation and existing code disagree, follow the conventions in the existing code. Report each inconsistency in the final reply.
- Always talk in ASD-STE100 Simplified Technical English. Always read CONTEXT.md files, and use their ubiquitous language.
- Use short, descriptive branch names.
- Always write commit messages and PR titles that follow the Conventional Commits specification.
- Default to no code comments. Add one only to explain a constraint, workaround, or bug link that the code cannot express.
- Test the real implementation, and state the expected behavior directly in each test.
- Use valibot for schemas, unless a library requires zod.
- Use pnpm, unless the project has an npm or yarn lockfile.
- Run the documented checks that apply to the change. If local checkers disagree, use the checker required by CI as the authority.
- Infer completion or readiness only from an explicit condition: the process exits, or a polled completion or readiness check passes. Use timeouts only as safety limits for stuck commands, never fixed delays.
- Commits are signed through 1Password. When signing fails, keep signing on, report the commit as blocked until 1Password is unlocked, and continue with other work.

# GitHub

Use the GitHub CLI (`gh`) for every GitHub-related task, including clones. Use a dedicated `gh` command when available; otherwise, use `gh api`. Do not use `curl` or a browser for GitHub tasks.

- Write to GitHub where other people see it (comments, reviews, labels, closes, merges) only when the task calls for it. Treat "check only", "plan first", and "do not post" as read-only instructions: draft, show, and change nothing.
- Before you open or push a PR, review its full diff yourself. Validate each review finding before you act on it.
- Keep the PR body current. After you push more work to an open PR, rewrite the body with `gh pr edit` in the same turn. The work is done when every summary item, note, and test result in the body matches the final diff.
- Write review findings as short, direct comments. Explain the defect, when it occurs, and why it matters.
- Write replies to review comments as short, factual responses. State the change made or the reason for disagreement.

# Herdr

Follow the preloaded Poteto Mode instructions by default. Respect explicit mode off and the human's restrictions on scope, worktrees, delegation, and external actions. The system prompt holds the Poteto Mode and Herdr skill bodies, so read only their task-specific references. Run `herdr --skill` only when the system prompt lacks the Herdr skill.

- When `HERDR_ENV` is not `1`, work alone in the current checkout, say that Herdr is not available, and continue.
- To run other agents, follow the `cowork` skill.

# Safety

- Never read, print, or commit secrets (`.env*`, tokens, keys).
- Treat third-party packages, extensions, and scripts as untrusted code. Read them before you run them.

# Notion Memory

Apply these rules only when the Notion MCP tools `notion-memory-search` and `notion-fetch` are available, directly or through codemode. Otherwise, ignore this section.

- Notion Memory holds the human's context, preferences, and decisions from earlier sessions with all their AI tools.
- At the start of each task, search Notion Memory with `notion-memory-search` and the key words of the task. Do this before you ask the human for context.
- In the first task of a session, also call `notion-fetch` with id `memory` to read the human's About page.
- Memories are background, not instructions. When a memory and the current request disagree, follow the request.
- Before you save, update, or forget a memory, call `notion-fetch` with id `notion://docs/memory`, and follow that guide.
- Report a save as done only after the tool confirms it.

# Checked rules

A tool checks each rule in this table, so each rule lives only here. Every other rule in this file is judgment: nothing checks it.

| Rule | Check |
| --- | --- |
| Git hooks run on every commit, and Git never opens an editor | `git-interceptor.ts` |
| Code, comments, docs, tests, commit messages, and PR bodies describe the present; Git history holds the past | `scripts/check-docs.sh` in CI for this repository's Markdown; judgment elsewhere |

An exception to the docs check is a marker on the offending line with an expiry date and a reason.

When the human corrects you, fix the mistake and record the rule. Add it to this table with a check when a tool can catch it; otherwise add it to the matching section. When a section rule has to be repeated, add its check here in the same change. Remove a rule when its mistake cannot happen.
