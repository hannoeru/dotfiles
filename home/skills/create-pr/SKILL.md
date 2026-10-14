---
name: create-pr
description: Open one GitHub pull request for the current change. Use when the user asks to open, create, publish, or prepare a PR. The title is a Conventional Commit. The body uses a Summary visual, Evidence, and Merge Danger.
---

# Create a pull request

Open one pull request for one change. A reviewer should understand the changed behavior from the body alone. Explain what changed and why. Keep the body proportional to the change.

## Workflow

1. Inspect the repo: `git status`, the current branch, remotes, the default branch, `.github/PULL_REQUEST_TEMPLATE*`, and `AGENTS.md` or `CONTRIBUTING.md` for PR rules.
2. Compute the merge base against the target branch and record the exact `base...head` range this PR publishes. If the branch is stacked on another unmerged branch, target that branch and describe only this PR's own changes.
3. Read the full diff. Separate runtime code from generated files, lockfiles, and snapshots. Trace changed code to its entry points, callers, and external boundaries so architecture claims name a file path or symbol.
4. If the branch contains more than one change, stop. Split the unrelated work into its own branch and its own PR before opening this one. One PR contains one change.
5. Run the checks that match the changed surfaces (focused tests, typecheck, lint, or the repo's own check). Record the exact commands and results.
6. If the diff changes user-visible UI, capture before and after evidence from the merge base and the PR head. Use the same viewport, theme, locale, fixture data, and readiness condition. Write images to an ignored directory such as `.pr-shots/`. Do not commit them.
7. Review the commit history. Each commit does one logical thing and uses a Conventional Commits message. Reshape unpushed commits with `git rebase -i <base>` until `git log --oneline` reads as the story of this one change. Do not rewrite commits that are already pushed and under review; add new commits instead.
8. Write the body to a temporary file using the template below. If the repo has a PR template, fill that template and place Summary, Evidence, and Merge Danger inside it.
9. Push the branch. Create the PR with `gh pr create --title ... --body-file ...`. Add `--attach` for each screenshot. Use `--draft` when checks are still running or the work is not review-ready.
10. Open the created PR and verify the title, base, head, rendered visuals, and images.
11. For review comments: fix each confirmed issue, run focused checks, push, reply with evidence, and resolve the thread.

## Title

Use a Conventional Commits title, matching how this repo writes commit messages. Lowercase, imperative, no trailing period, under about 70 characters. Include a scope when the repo already scopes commits that way. Omit the scope when the change is repo-wide.

```text
feat(scope): add retry to upload client
fix(scope): avoid double submit on enter
refactor: extract diff parsing from cli
chore(deps): update vite to v8
docs: clarify worktree setup
```

Squash-merge repos turn the title into the commit message. Write the title as the commit you want in history.

## Body

Skip preambles. Use the repository's own terms. Start at the Summary heading.

Pick the smallest view that makes the key point clear. One visual is usual. Several are rare. Do not use every view.

Views:

- Pseudocode for logic or an algorithm.
- A call tree for runtime control flow.
- A component tree for UI structure, including the state and module boundaries that matter.
- A shallow file tree for responsibility or a broad refactor.
- Mermaid for component interaction, control flow, or data flow.
- A `diff` block when the point is what changes and the surrounding shape already exists.
- A short whole block when most of it is new, when omitted context would hide ownership or order, or when the reviewer needs a copyable target shape.

Place each visual next to the short text it supports. Keep only the calls, files, props, states, and boundaries the reviewer needs.

```markdown
## Summary

<diagram, diff-sketch, or tree>

<one or two sentences only when the visual needs them>

closes #123

## Evidence

- **Before:** <screenshot, command output, or failing test>
  **After:** <screenshot, command output, or passing test>

## Merge Danger

**Door:** <one-way or two-way>

**Blast Radius:** <short scope>

<what could break, if anything>
```

### Evidence

Show a before and an after. A screenshot is the strongest evidence when the change is visual and the environment can capture one. Otherwise show the exact test that failed and now passes, or the command output that changed. Name the command. "Tests passed" by itself is a claim, not evidence.

Say what is verified, what is assumed, and what is not verified. Do not write "safe", "fixed", or "backward compatible" without pointing at the evidence. Green CI proves only the checks CI runs.

Attach screenshots with `gh pr create --attach`. Paths in `--attach` must match the paths written in the body. Do not commit screenshots or other PR-only artifacts. Do not paste tokens, secrets, user records, or full payloads.

### Merge Danger

A two-way door is cheap to reverse. A one-way door is a destructive action or a hard-to-reverse decision, such as a schema migration, a public API removal, or data that has already been sent. Blast radius is what could break if the change is wrong: layout shift, API consumers, mobile layout, and the same class of effect.

## Rules

- One PR per change. Unrelated fixes, dependency bumps, and drive-by refactors get their own PRs.
- Do not describe inherited changes from a parent branch as this PR's changes.
- Link an issue with `closes #123`, `fixes #123`, or `refs #123` when this change belongs to one. If several issues apply and the user has not chosen one, ask before opening the PR.
- For a stacked PR, name the parent and which commits belong to this PR.
- If an agent wrote the PR, say so in one line at the end of the body.
