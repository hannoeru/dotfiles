import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
	DefaultResourceLoader,
	ExtensionRunner,
	ModelRegistry,
	ModelRuntime,
	SessionManager,
	SettingsManager,
	type ToolCallEvent,
} from "@earendil-works/pi-coding-agent";
import { afterAll, beforeAll, describe, expect, test } from "vitest";
import agentGuard from "../extensions/agent-guard.ts";

const WORKER_APPEND = "You are a worker agent. Follow ~/.pi/agent/workflow/worker.md.";
const CONTEXT_QUOTING_MARKER = `Workers are sessions whose appended prompt says \`${WORKER_APPEND}\``;

let root: string;
const dirs = { repo: "", npmRoot: "", npmPackage: "", yarnRoot: "", noRepo: "" };
const runners = new Map<string, ExtensionRunner>();

beforeAll(() => {
	root = mkdtempSync(join(tmpdir(), "pi-agent-guard-"));
	const repo = (name: string, lockfile?: string) => {
		const dir = join(root, name);
		execFileSync("git", ["init", "-q", dir]);
		if (lockfile) writeFileSync(join(dir, lockfile), "{}");
		return dir;
	};
	dirs.repo = repo("repo");
	dirs.npmRoot = repo("npm", "package-lock.json");
	dirs.npmPackage = join(dirs.npmRoot, "packages", "app");
	mkdirSync(dirs.npmPackage, { recursive: true });
	dirs.yarnRoot = repo("yarn", "yarn.lock");
	dirs.noRepo = join(root, "no-repo");
	mkdirSync(dirs.noRepo);
});

afterAll(() => rmSync(root, { recursive: true, force: true }));

async function runnerFor(cwd: string) {
	const existing = runners.get(cwd);
	if (existing) return existing;
	const loader = new DefaultResourceLoader({
		cwd,
		agentDir: join(root, "agent"),
		settingsManager: SettingsManager.inMemory({}),
		noExtensions: true,
		noSkills: true,
		noPromptTemplates: true,
		noThemes: true,
		extensionFactories: [agentGuard],
	});
	await loader.reload();
	const loaded = loader.getExtensions();
	expect(loaded.errors).toEqual([]);
	const runtime = await ModelRuntime.create({ authPath: join(root, "auth.json"), modelsPath: null, refreshOnCreate: false });
	const runner = new ExtensionRunner(loaded.extensions, loaded.runtime, cwd, SessionManager.inMemory(cwd), new ModelRegistry(runtime));
	runners.set(cwd, runner);
	return runner;
}

type Options = { cwd?: string; appendSystemPrompt?: string };

async function emit(event: ToolCallEvent, { cwd = dirs.repo, appendSystemPrompt = "" }: Options = {}) {
	const runner = await runnerFor(cwd);
	await runner.emitBeforeAgentStart(
		{ messageType: "user", prompt: "task" },
		{ cwd, appendSystemPrompt, contextFiles: [{ path: "AGENTS.md", content: CONTEXT_QUOTING_MARKER }], sections: {} },
	);
	return runner.emitToolCall(event);
}

const bash = (command: string, options?: Options) =>
	emit({ type: "tool_call", toolCallId: "t", toolName: "bash", input: { command } }, options);

async function expectBlocked(command: string, reason: string, options?: Options) {
	expect(await bash(command, options)).toEqual({ block: true, reason: expect.stringMatching(new RegExp(`^BLOCKED: .*${reason}`)) });
}

async function expectAllowed(command: string, options?: Options) {
	expect(await bash(command, options)).toBeUndefined();
}

describe("Herdr server", () => {
	test.each(["herdr server stop", "herdr --machine m server stop"])("blocks %j", (command) =>
		expectBlocked(command, "Leave the server running"),
	);

	test.each(["herdr server status", "herdr workspace list"])("allows %j", (command) => expectAllowed(command));
});

describe("agent dialogs", () => {
	test.each(["herdr agent send-keys w-x enter", "herdr pane send-keys w1:p2 y", "herdr pane send-text w1:p2 yes"])(
		"blocks %j",
		(command) => expectBlocked(command, "Leave agent dialogs unanswered"),
	);

	test.each(["herdr agent read w-x --source visible", "herdr pane run w1:p2 'pnpm test'", "herdr agent prompt w-x 'go'"])(
		"allows %j",
		(command) => expectAllowed(command),
	);
});

describe("worktrees", () => {
	test.each(["add", "remove", "move", "prune", "repair", "lock", "unlock"])("blocks git worktree %s", (sub) =>
		expectBlocked(`git worktree ${sub} ../x`, "herdr worktree create"),
	);

	test("blocks a worktree change behind a value option", () => expectBlocked("git -C /repo worktree add ../x", "herdr worktree create"));

	test.each(["git worktree list", "git -C /repo worktree list --porcelain", "herdr worktree create --branch x"])("allows %j", (command) =>
		expectAllowed(command),
	);
});

describe(".agent reports", () => {
	test.each(["git add .agent/report.md", "git add -f .agent", "git add src sub/.agent/review.md"])("blocks %j", (command) =>
		expectBlocked(command, "stay out of Git"),
	);

	test.each(["git add .agents/skills/x/SKILL.md", "git add src/agent.ts", "git status .agent"])("allows %j", (command) =>
		expectAllowed(command),
	);
});

describe("worker limits", () => {
	const worker = { appendSystemPrompt: `Project notes.\n\n${WORKER_APPEND}` };

	test.each([
		"git push",
		"git push -u origin x",
		"git merge x",
		"git rebase main",
		"git rebase origin/main",
		"git pull --rebase origin main",
		"git branch -d x",
		"git branch -D x",
		"git branch --delete x",
		"gh pr create --fill",
		"gh pr edit 1 --body-file b.md",
		"gh pr ready 1",
		"gh pr merge 1",
		"herdr agent start r-x --kind pi --pane w1:p2",
		"herdr agent prompt w-x go",
		"herdr worktree create --branch x",
		"herdr workspace list",
	])("blocks %j for a worker", (command) => expectBlocked(command, "Workers commit on their own branch only", worker));

	test.each([
		"git commit -m x",
		"git status",
		"git rebase -i HEAD~2",
		"git pull",
		"git branch x",
		"gh pr view 1",
		"gh issue view 1",
		"herdr agent read w-x",
		"herdr pane split --current --direction down --no-focus",
	])("allows %j for a worker", (command) => expectAllowed(command, worker));

	test.each(["git push", "gh pr create --fill", "herdr agent prompt w-x go"])(
		"allows %j when only a context file quotes the worker marker",
		(command) => expectAllowed(command, { appendSystemPrompt: "You are a reviewer." }),
	);

	test.each([
		"timeout 60 git push",
		"env FOO=1 git push",
		"echo x | xargs -n 1 git push",
		"bash -c 'git push'",
		"eval 'git push'",
		"find . -name x -exec git push \\;",
		"watch -n 5 git push",
		"git status && git push",
	])("blocks a wrapped or chained push: %j", (command) => expectBlocked(command, "Workers commit on their own branch only", worker));

	test.each(["echo 'git push'", "git commit -m 'then git push'"])("allows text that only mentions a push: %j", (command) =>
		expectAllowed(command, worker),
	);
});

describe("package managers", () => {
	test.each(["npm install", "npm i x", "npm ci", "npm run build", "npm create vite@latest app", "npm init -y", "npx tsx a.ts"])(
		"blocks %j in a repository without an npm lockfile",
		(command) => expectBlocked(command, "does not use npm"),
	);

	test.each(["yarn", "yarn add x", "yarn install"])("blocks %j in a repository without a yarn lockfile", (command) =>
		expectBlocked(command, "does not use yarn"),
	);

	test("blocks npm outside any repository", () => expectBlocked("npm install", "does not use npm", { cwd: dirs.noRepo }));

	test.each([
		["npm ci", "npmRoot"],
		["npx tsx a.ts", "npmRoot"],
		["npm run build", "npmPackage"],
		["yarn install", "yarnRoot"],
	] as const)("allows %j where the lockfile is at or above the directory (%s)", (command, dir) =>
		expectAllowed(command, { cwd: dirs[dir] }),
	);

	test.each(["npm --version", "yarn -v", "npm view x version", "pnpm add x", "pnpm dlx create-vite", "bun add x"])(
		"allows %j in any repository",
		(command) => expectAllowed(command),
	);
});

test("ignores tool calls other than bash", async () => {
	expect(await emit({ type: "tool_call", toolCallId: "t", toolName: "read", input: { path: "herdr server stop" } })).toBeUndefined();
});
