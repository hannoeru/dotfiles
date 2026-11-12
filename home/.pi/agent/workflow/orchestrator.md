# Orchestrator

Keep the main checkout clean, so that every worktree branches from it.

## 0. Once per repository

If `.agent/` is not in `.git/info/exclude` of the main checkout, add it. All worktrees share this file, so worker reports stay out of Git.

## 1. Plan

Split the request into independent tasks that touch different files: one file, one owner. For each task, write a slug, the files that it owns, the new dependencies that it adds, and acceptance criteria: what "done" means and which commands prove it. Show the plan to the human and wait for approval before you dispatch. Start with 2 or 3 workers, and run at most 5 at the same time.

## 2. Dispatch each task

Dispatch all tasks before you wait on any of them.

```sh
herdr worktree create --cwd <main-checkout> --branch agent/<slug> --label w-<slug> --no-focus
# read .result.root_pane.pane_id -> <pane>

herdr agent start w-<slug> --kind pi --pane <pane> -- --append-system-prompt "You are a worker agent. Follow ~/.pi/agent/workflow/worker.md."

herdr pane report-metadata <pane> --source user:orchestrator --agent pi --token summary="<2-4 words>"

herdr agent prompt w-<slug> "<task>. You own: <files>. Done when: <criteria>."
```

- To select the worker's model, add `--model <provider/id>` or `--thinking <level>` after `--`.
- If `agent start` fails because the shell is not at its prompt yet, retry once.
- If Pi stops at startup to ask whether to trust the folder, tell the human, and leave the question for the human.

## 3. Wait

Wait only with `herdr agent wait w-<slug> --timeout 1800000`, one call for each worker, never with a sleep or a poll loop. It returns on idle, done, or blocked. If a wait times out, report the progress to the human and stop. A settled state does not mean that the task is finished.

## 4. Collect the report

Run `herdr agent read w-<slug> --source visible`, find the worker's `REPORT: <path>` line, and read that file. The task is finished only when the line is there, the file exists, and it says `Status: done`. If there is no `REPORT:` line, read more (`--source recent-unwrapped --lines 120`) to find the cause. Then send a follow-up or tell the human.

## 5. Review

From the main checkout, and without editing the worktree, run `git --no-pager log --oneline main..agent/<slug>` and `git --no-pager diff main...agent/<slug>`. Make sure that the commits in the report exist and that the change meets the acceptance criteria.

For a risky change, add an independent reviewer from a different model family in the worker's tab:

```sh
herdr pane split <worker-pane> --direction down --no-focus
# read .result.pane.pane_id -> <review-pane>
herdr agent start r-<slug> --kind pi --pane <review-pane> -- --model <other-family-model> --append-system-prompt "You are a reviewer. Change only the review file that your prompt names."
herdr agent prompt r-<slug> "Review git diff main...HEAD against: <criteria>. Write findings to .agent/review.md, each tagged BLOCKING or NON-BLOCKING, ending with one line: VERDICT: APPROVED or VERDICT: CHANGES. Then reply with REPORT: <absolute path>."
```

## 6. Follow up

Send fixes with `herdr agent prompt w-<slug> "<what to change>"`, then go back to step 3. Do at most 3 fix rounds for each task. After that, stop and ask the human.

## 7. Report to the human

Write one row for each task: branch, status, summary, review verdict, and decisions needed. The human merges. When the human asks for a PR, push the reviewed branch and open the PR from the main checkout. Clean up only when the human asks: run `herdr worktree remove --workspace <id>` (get the ID from `herdr workspace list`). This command keeps the branch.

## Rules

- Push, merge, and delete branches only when the human asks.
