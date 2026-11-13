import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { positionals, programCalls } from "./shell/commands.ts";
import { GIT_VALUE_OPTIONS } from "./shell/git.ts";

type Rule = (args: string[], cwd: string) => string | undefined;

const DIALOG_REASON = "Leave agent dialogs unanswered. Report the task as blocked with the dialog text.";
const WORKER_MARKER = "You are a worker agent.";
const WORKER_REASON =
	"Workers commit on their own branch only. Write a `Status: blocked` report for anything else: " +
	"push, merge, rebase onto main, branch deletion, pull requests, or control of agents and worktrees.";

const GH_VALUE_OPTIONS = new Set(["-R", "--repo", "-t", "--title", "-b", "--body", "-F", "--body-file", "-B", "--base", "-H", "--head"]);
const HERDR_VALUE_OPTIONS = new Set(["--machine", "--session", "--remote", "--kind", "--pane", "--timeout", "--workspace", "--cwd", "--branch", "--base", "--path", "--label", "--source", "--lines", "--format", "--until", "--direction", "--ratio", "--env"]);

const herdr: Rule = (args) => {
	const [group, sub] = positionals(args, HERDR_VALUE_OPTIONS);
	if (group === "server" && sub === "stop") return "`herdr server stop` ends every pane, including the human's. Leave the server running.";
	if ((group === "agent" && sub === "send-keys") || (group === "pane" && (sub === "send-keys" || sub === "send-text"))) {
		return DIALOG_REASON;
	}
	return undefined;
};

const GIT_WORKTREE_WRITES = new Set(["add", "remove", "move", "prune", "repair", "lock", "unlock"]);
const AGENT_REPORTS = /(?:^|\/)\.agent(?:\/|$)/;
const MAIN_BRANCH = /^(?:origin\/)?(?:main|master)$/;

const git: Rule = (args) => {
	const [sub, ...rest] = positionals(args, GIT_VALUE_OPTIONS);
	if (sub === "worktree" && GIT_WORKTREE_WRITES.has(rest[0])) {
		return "Herdr owns every worktree. Use `herdr worktree create` or `herdr worktree remove`.";
	}
	if (sub === "add" && rest.some((path) => AGENT_REPORTS.test(path))) {
		return "Reports under `.agent/` stay out of Git. Commit only your source changes.";
	}
	return undefined;
};

const WORKER_LIMITS: Record<string, (args: string[]) => boolean> = {
	git: (args) => {
		const [sub, ...rest] = positionals(args, GIT_VALUE_OPTIONS);
		const deletesBranch = sub === "branch" && args.some((arg) => ["-d", "-D", "--delete"].includes(arg));
		const takesMain = (sub === "rebase" || sub === "pull") && rest.some((ref) => MAIN_BRANCH.test(ref));
		return sub === "push" || sub === "merge" || deletesBranch || takesMain;
	},
	gh: (args) => {
		const [group, sub] = positionals(args, GH_VALUE_OPTIONS);
		return group === "pr" && ["create", "edit", "ready", "merge"].includes(sub);
	},
	herdr: (args) => {
		const [group, sub] = positionals(args, HERDR_VALUE_OPTIONS);
		return group === "worktree" || group === "workspace" || (group === "agent" && ["start", "prompt", "send-keys"].includes(sub));
	},
};

type PackageManager = { name: string; lockfiles: string[]; guarded: (sub: string | undefined) => boolean };

const NPM_LOCKFILES = ["package-lock.json", "npm-shrinkwrap.json"];
const NPM_PROJECT_SUBCOMMANDS = new Set(["install", "i", "ci", "add", "run", "exec", "x", "test", "start", "update", "create", "init"]);
const PACKAGE_VALUE_OPTIONS = new Set(["--filter", "-F", "-C", "--dir", "--prefix", "-w", "--workspace", "--registry"]);
const INFO_FLAGS = new Set(["--version", "-v", "--help", "-h"]);
const PACKAGE_MANAGERS: Record<string, PackageManager> = {
	npm: { name: "npm", lockfiles: NPM_LOCKFILES, guarded: (sub) => sub !== undefined && NPM_PROJECT_SUBCOMMANDS.has(sub) },
	npx: { name: "npm", lockfiles: NPM_LOCKFILES, guarded: () => true },
	yarn: { name: "yarn", lockfiles: ["yarn.lock"], guarded: () => true },
	pnpm: { name: "pnpm", lockfiles: [], guarded: () => false },
	bun: { name: "bun", lockfiles: [], guarded: () => false },
};

function projectUses(cwd: string, lockfiles: string[]) {
	for (let dir = cwd; ; dir = dirname(dir)) {
		if (lockfiles.some((name) => existsSync(join(dir, name)))) return true;
		if (existsSync(join(dir, ".git")) || dirname(dir) === dir) return false;
	}
}

function packageRule(program: string): Rule {
	const { name, lockfiles, guarded } = PACKAGE_MANAGERS[program];
	return (args, cwd) => {
		if (args.length > 0 && args.every((arg) => INFO_FLAGS.has(arg))) return undefined;
		const [sub] = positionals(args, PACKAGE_VALUE_OPTIONS);
		if (guarded(sub) && !projectUses(cwd, lockfiles)) {
			return `This project does not use ${name}. Use pnpm: \`pnpm create\` for new projects, \`pnpm dlx\` for one-off tools.`;
		}
		return undefined;
	};
}

const RULES: Record<string, Rule> = {
	herdr,
	git,
	...Object.fromEntries(Object.keys(PACKAGE_MANAGERS).map((program) => [program, packageRule(program)])),
};

function blockReasons(command: string, cwd: string, worker: boolean): string[] {
	const reasons: string[] = [];
	const calls = programCalls(command);
	for (const { program, args } of calls) {
		const reason = RULES[program]?.(args, cwd);
		if (reason) reasons.push(reason);
		if (worker && WORKER_LIMITS[program]?.(args)) reasons.push(WORKER_REASON);
	}
	return reasons;
}

export default function agentGuard(pi: ExtensionAPI): void {
	let worker = false;
	pi.on("before_agent_start", ({ systemPromptOptions }) => {
		worker = systemPromptOptions.appendSystemPrompt.includes(WORKER_MARKER);
	});

	pi.on("tool_call", (event, ctx) => {
		if (!isToolCallEventType("bash", event)) return;
		const [reason] = blockReasons(event.input.command, ctx.cwd, worker);
		if (reason) return { block: true, reason: `BLOCKED: ${reason}` };
	});
}
