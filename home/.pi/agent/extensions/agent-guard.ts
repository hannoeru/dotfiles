import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { optionValues, positionals, programCalls } from "./shell/commands.ts";
import { GIT_VALUE_OPTIONS } from "./shell/git.ts";

type Verdict = { kind: "block" | "confirm"; reason: string };
type Rule = (args: string[], cwd: string) => Verdict | undefined;
type Role = "orchestrator" | "worker";

const block = (reason: string): Verdict => ({ kind: "block", reason });
const confirm = (reason: string): Verdict => ({ kind: "confirm", reason });

const GITHUB_WRITE_REASON =
	"This writes to GitHub where other people see it. Draft the text for the human and post only when the human asks.";
const DIALOG_REASON = "Tell the human what the agent asks. The human answers its dialogs.";
const WORKER_REASON =
	"Workers commit on their own branch only. Write a `Status: blocked` report for anything else: " +
	"push, merge, rebase onto main, branch deletion, pull requests, or control of agents and worktrees.";

const GH_VALUE_OPTIONS = new Set(["-R", "--repo", "-X", "--method", "-f", "-F", "--field", "--raw-field", "--input", "-H", "--header", "-b", "--body", "--body-file", "-t", "--title", "-q", "--jq", "-B", "--base"]);
const GH_WRITES: Record<string, Set<string>> = {
	issue: new Set(["create", "close", "reopen", "comment", "edit", "delete", "lock", "unlock", "pin", "unpin", "transfer", "develop"]),
	pr: new Set(["comment", "review", "close", "reopen", "merge", "lock", "unlock"]),
	label: new Set(["create", "edit", "delete", "clone"]),
	release: new Set(["create", "edit", "delete", "upload", "delete-asset"]),
	repo: new Set(["create", "delete", "edit", "archive", "unarchive", "rename"]),
	gist: new Set(["create", "edit", "delete", "rename"]),
	workflow: new Set(["run", "enable", "disable"]),
	run: new Set(["rerun", "cancel", "delete"]),
	secret: new Set(["set", "delete"]),
	variable: new Set(["set", "delete"]),
	cache: new Set(["delete"]),
};
const PR_EDIT_OWN_OPTIONS = new Set(["-t", "--title", "-b", "--body", "-F", "--body-file", "-B", "--base", "-R", "--repo"]);

function ghApiWrites(args: string[]) {
	const [method] = optionValues(args, ["-X", "--method"]);
	if (method) return method.toUpperCase() !== "GET";
	const fields = optionValues(args, ["-f", "-F", "--field", "--raw-field"]);
	const input = optionValues(args, ["--input"]).length > 0;
	if (positionals(args, GH_VALUE_OPTIONS)[1] !== "graphql") return input || fields.length > 0;
	return input || fields.some((field) => /^query=(?:@|\s*mutation\b)/.test(field));
}

const gh: Rule = (args) => {
	const [group, sub] = positionals(args, GH_VALUE_OPTIONS);
	const editsMetadata =
		group === "pr" && sub === "edit" && args.some((arg) => arg.startsWith("-") && !PR_EDIT_OWN_OPTIONS.has(arg.split("=")[0]));
	if (GH_WRITES[group]?.has(sub) || editsMetadata || (group === "api" && ghApiWrites(args))) return confirm(GITHUB_WRITE_REASON);
	return undefined;
};

const HERDR_VALUE_OPTIONS = new Set(["--machine", "--session", "--remote", "--kind", "--pane", "--timeout", "--workspace", "--cwd", "--branch", "--base", "--path", "--label", "--source", "--lines", "--format", "--until", "--direction", "--ratio", "--env"]);

const herdr: Rule = (args) => {
	const [group, sub] = positionals(args, HERDR_VALUE_OPTIONS);
	if (group === "server" && sub === "stop") return block("`herdr server stop` ends every pane, including the human's. Leave the server running.");
	if (group === "agent" && sub === "start") {
		const [kind] = optionValues(args, ["--kind"]);
		if (kind === undefined) return confirm("Start Pi agents with `--kind pi`.");
		if (kind !== "pi") return confirm(`Start Pi agents with \`--kind pi\`. Use \`--kind ${kind}\` only when the human asked for it.`);
	}
	if ((group === "agent" && sub === "send-keys") || (group === "pane" && (sub === "send-keys" || sub === "send-text"))) {
		return confirm(DIALOG_REASON);
	}
	return undefined;
};

const GIT_WORKTREE_WRITES = new Set(["add", "remove", "move", "prune", "repair", "lock", "unlock"]);
const AGENT_REPORTS = /(?:^|\/)\.agent(?:\/|$)/;
const MAIN_BRANCH = /^(?:origin\/)?(?:main|master)$/;

const git: Rule = (args) => {
	const [sub, ...rest] = positionals(args, GIT_VALUE_OPTIONS);
	if (sub === "worktree" && GIT_WORKTREE_WRITES.has(rest[0])) {
		return block("Herdr owns every worktree. Use `herdr worktree create` or `herdr worktree remove`.");
	}
	if (sub === "add" && rest.some((path) => AGENT_REPORTS.test(path))) {
		return block("Reports under `.agent/` stay out of Git. Commit only your source changes.");
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
const DEPENDENCY_ADDS: Record<string, Set<string>> = {
	npm: new Set(["install", "i", "add"]),
	yarn: new Set(["add"]),
	pnpm: new Set(["add", "install", "i"]),
	bun: new Set(["add", "install", "i"]),
};

function dependencyReason(packages: string[]) {
	const zod = packages.some((pkg) => /^zod(?:@|$)/.test(pkg)) ? " Use valibot for schemas, unless a library requires zod." : "";
	return `Ask the human before you add a dependency. Packages: ${packages.join(", ")}.${zod}`;
}

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
		const [sub, ...packages] = positionals(args, PACKAGE_VALUE_OPTIONS);
		if (guarded(sub) && !projectUses(cwd, lockfiles)) {
			return block(`This project does not use ${name}. Use pnpm: \`pnpm create\` for new projects, \`pnpm dlx\` for one-off tools.`);
		}
		if (sub !== undefined && DEPENDENCY_ADDS[program]?.has(sub) && packages.length > 0) return confirm(dependencyReason(packages));
		return undefined;
	};
}

const RULES: Record<string, Rule> = {
	gh,
	herdr,
	git,
	...Object.fromEntries(Object.keys(PACKAGE_MANAGERS).map((program) => [program, packageRule(program)])),
};

const roles = new Map<string, Role>();

function detectRole(cwd: string): Role {
	try {
		const [gitDir, commonDir] = execFileSync("git", ["rev-parse", "--path-format=absolute", "--git-dir", "--git-common-dir"], {
			cwd,
			encoding: "utf8",
			stdio: ["ignore", "pipe", "ignore"],
		})
			.trim()
			.split("\n");
		return gitDir === commonDir ? "orchestrator" : "worker";
	} catch (error) {
		return error instanceof Error && "status" in error && error.status === 128 ? "orchestrator" : "worker";
	}
}

function sessionRole(cwd: string): Role {
	let role = roles.get(cwd);
	if (!role) {
		role = detectRole(cwd);
		roles.set(cwd, role);
	}
	return role;
}

function checkCommand(command: string, cwd: string): Verdict[] {
	const verdicts: Verdict[] = [];
	const calls = programCalls(command);
	const worker = calls.some(({ program }) => program in WORKER_LIMITS) && sessionRole(cwd) === "worker";
	for (const { program, args } of calls) {
		const verdict = RULES[program]?.(args, cwd);
		if (verdict) verdicts.push(verdict);
		if (worker && WORKER_LIMITS[program]?.(args)) verdicts.push(confirm(WORKER_REASON));
	}
	return verdicts;
}

export default function agentGuard(pi: ExtensionAPI): void {
	pi.on("tool_call", async (event, ctx) => {
		if (!isToolCallEventType("bash", event)) return;
		const verdicts = checkCommand(event.input.command, ctx.cwd);
		const blocked = verdicts.find((verdict) => verdict.kind === "block");
		if (blocked) return { block: true, reason: `BLOCKED: ${blocked.reason}` };
		if (verdicts.length === 0) return;

		const reasons = [...new Set(verdicts.map((verdict) => verdict.reason))].join("\n");
		const approved = ctx.hasUI && (await ctx.ui.confirm("Allow this command?", `${reasons}\n\n${event.input.command}`));
		if (!approved) return { block: true, reason: `BLOCKED: the human did not approve this command. ${reasons}` };
	});
}
