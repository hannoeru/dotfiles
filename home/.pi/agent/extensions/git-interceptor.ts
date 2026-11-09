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

const GIT_ENV_PREFIX =
	"export GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no\n";

const COMMAND_PREFIXES = new Set([
	"!",
	"{",
	"if",
	"then",
	"elif",
	"else",
	"while",
	"until",
	"do",
	"time",
	"command",
	"env",
	"exec",
	"nohup",
	"sudo",
]);
const GIT_VALUE_OPTIONS = new Set([
	"-C",
	"-c",
	"--git-dir",
	"--work-tree",
	"--namespace",
	"--config-env",
	"--attr-source",
]);
const COMMIT_LONG_VALUE_OPTIONS = new Set(["--message", "--file", "--author", "--date", "--trailer"]);
const COMMIT_CLUSTER_HAS_N = /^-[^-mFCctuS]*n/;
const COMMIT_CLUSTER_ENDS_WITH_VALUE_OPTION = /^-[^-mFCctuS]*[mFCct]$/;

const BLOCK_REASON =
	"BLOCKED: Git hook bypass flags are not allowed. Git hooks exist for a reason. " +
	"Do not attempt to bypass them. Instead: fix the underlying issue that " +
	"is causing the hook to fail, or ask the user for help.";

function parseSimpleCommands(script: string): string[][] {
	const commands: string[][] = [];
	const heredocs: { delimiter: string; stripTabs: boolean }[] = [];
	let words: string[] = [];
	let word: string | undefined;
	let pendingHeredoc: { stripTabs: boolean } | undefined;

	const endWord = () => {
		if (word === undefined) return;
		if (pendingHeredoc) heredocs.push({ delimiter: word, ...pendingHeredoc });
		else words.push(word);
		pendingHeredoc = undefined;
		word = undefined;
	};
	const endCommand = () => {
		endWord();
		if (words.length > 0) commands.push(words);
		words = [];
	};

	for (let i = 0; i < script.length; i++) {
		const char = script[i];
		if (char === "'") {
			const end = script.indexOf("'", i + 1);
			const close = end === -1 ? script.length : end;
			word = (word ?? "") + script.slice(i + 1, close);
			i = close;
		} else if (char === '"') {
			word ??= "";
			for (i++; i < script.length && script[i] !== '"'; i++) {
				if (script[i] === "\\") i++;
				word += script[i] ?? "";
			}
		} else if (char === "\\") {
			i++;
			if (i < script.length && script[i] !== "\n") word = (word ?? "") + script[i];
		} else if (char === "#" && word === undefined) {
			const newline = script.indexOf("\n", i);
			i = (newline === -1 ? script.length : newline) - 1;
		} else if (char === "\n") {
			endCommand();
			for (const heredoc of heredocs.splice(0)) i = skipHeredoc(script, i + 1, heredoc);
		} else if (";&|()`".includes(char)) {
			endCommand();
		} else if (script.startsWith("<<<", i)) {
			endWord();
			i += 2;
		} else if (script.startsWith("<<", i)) {
			endWord();
			const stripTabs = script[i + 2] === "-";
			pendingHeredoc = { stripTabs };
			i += stripTabs ? 2 : 1;
		} else if (char === "<" || char === ">") {
			endWord();
			if (script[i + 1] === "&" || script[i + 1] === "|") i++;
		} else if (char === " " || char === "\t") {
			endWord();
		} else {
			word = (word ?? "") + char;
		}
	}
	endCommand();
	return commands;
}

function skipHeredoc(
	script: string,
	bodyStart: number,
	{ delimiter, stripTabs }: { delimiter: string; stripTabs: boolean },
) {
	let lineStart = bodyStart;
	while (lineStart < script.length) {
		const newline = script.indexOf("\n", lineStart);
		const lineEnd = newline === -1 ? script.length : newline;
		const line = script.slice(lineStart, lineEnd);
		if ((stripTabs ? line.replace(/^\t+/, "") : line) === delimiter) return lineEnd;
		lineStart = lineEnd + 1;
	}
	return script.length;
}

function gitArguments(words: string[]) {
	const start = words.findIndex(
		(word) => !COMMAND_PREFIXES.has(word) && !word.startsWith("-") && !/^[A-Za-z_]\w*=/.test(word),
	);
	return start !== -1 && /(?:^|\/)git$/.test(words[start]) ? words.slice(start + 1) : undefined;
}

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

		const hasBypass = parseSimpleCommands(event.input.command).some((words) => {
			const args = gitArguments(words);
			return args !== undefined && bypassesHooks(args);
		});
		if (hasBypass) {
			return { block: true, reason: BLOCK_REASON };
		}

		event.input.command = GIT_ENV_PREFIX + event.input.command;
	});
}
