/**
 * Git Interceptor
 *
 * Two guards for agent-driven git commands:
 *
 * 1. Editor hang prevention — Sets GIT_EDITOR, GIT_SEQUENCE_EDITOR to `true`
 *    (no-op) and GIT_MERGE_AUTOEDIT to `no` so git never spawns an interactive
 *    editor (nvim, vim, etc.) that would hang the bash process.
 *
 * 2. Hook bypass prevention — Blocks `--no-verify`, its `git commit -n` alias
 *    (also in short-flag clusters), and `git -c core.hooksPath=...` so the
 *    agent cannot circumvent git hooks (pre-commit, commit-msg, etc.). Only
 *    real arguments of a real git invocation count: quoted text, heredoc
 *    bodies, comments, and other commands do not. The agent should fix hook
 *    failures or ask the human for help.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { programCalls } from "./shell/commands.ts";
import { GIT_VALUE_OPTIONS } from "./shell/git.ts";

const GIT_ENV_PREFIX =
	"export GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no\n";

const COMMIT_LONG_VALUE_OPTIONS = new Set(["--message", "--file", "--author", "--date", "--trailer"]);
const COMMIT_CLUSTER_HAS_N = /^-[^-mFCctuS]*n/;
const COMMIT_CLUSTER_ENDS_WITH_VALUE_OPTION = /^-[^-mFCctuS]*[mFCct]$/;

const BLOCK_REASON =
	"BLOCKED: Git hook bypass flags are not allowed. Git hooks exist for a reason. " +
	"Do not attempt to bypass them. Instead: fix the underlying issue that " +
	"is causing the hook to fail, or ask the human for help.";

function bypassesHooks(args: string[]) {
	let i = 0;
	for (; i < args.length && args[i].startsWith("-"); i++) {
		if (args[i] === "-c" && /^core\.hookspath(?:=|$)/i.test(args[i + 1] ?? "")) return true;
		if (GIT_VALUE_OPTIONS.has(args[i])) i++;
	}

	const isCommit = args[i] === "commit";
	for (i++; i < args.length && args[i] !== "--"; i++) {
		const arg = args[i];
		if (arg === "--no-verify") return true;
		if (!isCommit) continue;
		if (COMMIT_CLUSTER_HAS_N.test(arg)) return true;
		if (COMMIT_LONG_VALUE_OPTIONS.has(arg) || COMMIT_CLUSTER_ENDS_WITH_VALUE_OPTION.test(arg)) i++;
	}
	return false;
}

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", (event) => {
		if (!isToolCallEventType("bash", event)) return;
		if (!event.input.command.includes("git")) return;

		const hasBypass = programCalls(event.input.command).some(({ program, args }) => program === "git" && bypassesHooks(args));
		if (hasBypass) {
			return { block: true, reason: BLOCK_REASON };
		}

		event.input.command = GIT_ENV_PREFIX + event.input.command;
	});
}
