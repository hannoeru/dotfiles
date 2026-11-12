import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
	type BashToolCallEvent,
	DefaultResourceLoader,
	type ExtensionActions,
	type ExtensionContextActions,
	ExtensionRunner,
	type ExtensionUIContext,
	ModelRegistry,
	ModelRuntime,
	SessionManager,
	SettingsManager,
} from "@earendil-works/pi-coding-agent";
import { afterAll, beforeAll, describe, expect, test } from "vitest";
import agentGuard from "../extensions/agent-guard.ts";

let root: string;
let main: string;
let npmProject: string;
let npmPackage: string;
const runners = new Map<string, ExtensionRunner>();

beforeAll(() => {
	root = mkdtempSync(join(tmpdir(), "pi-agent-guard-"));
	main = join(root, "main");
	execFileSync("git", ["init", "-q", main]);
	npmProject = join(root, "npm-project");
	npmPackage = join(npmProject, "packages", "app");
	execFileSync("git", ["init", "-q", npmProject]);
	writeFileSync(join(npmProject, "package-lock.json"), "{}");
	mkdirSync(npmPackage, { recursive: true });
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

type Options = { cwd?: string; systemPrompt?: string };

async function run(command: string, { cwd = main, systemPrompt = "" }: Options = {}) {
	const runner = await runnerFor(cwd);
	runner.bindCore({} as ExtensionActions, { getSystemPrompt: () => systemPrompt } as ExtensionContextActions);
	const questions: string[] = [];
	const confirm = async (_title: string, message: string) => {
		questions.push(message);
		return false;
	};
	runner.setUIContext({ confirm } as unknown as ExtensionUIContext);
	const event: BashToolCallEvent = { type: "tool_call", toolCallId: "t", toolName: "bash", input: { command } };
	const result = await runner.emitToolCall(event);
	return { result, questions };
}

const allowed = { result: undefined, questions: [] };

describe("no command asks the human", () => {
	test.each([
		"gh issue close 294 --comment 'out of scope'",
		"gh pr comment 5369 --body-file /tmp/review.md",
		"gh pr merge 12 --squash",
		"gh api -XPOST repos/o/r/issues/1/labels",
		"gh pr create --title t --body-file b.md",
		"herdr agent start r-x --kind codex --pane w1:p2",
		"herdr agent start w-x --kind pi --pane w1:p2 -- --append-system-prompt 'You are a worker agent.'",
		"pnpm --filter web add -D zod",
		"pnpm install --frozen-lockfile",
		"git push",
		"echo 'herdr server stop'",
		"bash script.sh",
	])("runs: %s", async (command) => {
		expect(await run(command)).toEqual(allowed);
	});
});

describe("Herdr", () => {
	test.each([
		["herdr server stop", "Leave the server running"],
		["herdr agent send-keys w-x enter", "Leave agent dialogs unanswered"],
		["herdr pane send-text w1:p2 y", "Leave agent dialogs unanswered"],
	])("blocks %s without a dialog", async (command, reason) => {
		const { result, questions } = await run(command);
		expect(questions).toEqual([]);
		expect(result).toMatchObject({ block: true, reason: expect.stringContaining(reason) });
	});
});

describe("worktrees and workers", () => {
	test.each([
		["git worktree add ../x -b x", "herdr worktree create"],
		["git -C /repo worktree remove ../x", "herdr worktree create"],
		["git add -f .agent/report.md", "stay out of Git"],
	])("blocks %s", async (command, reason) => {
		const { result } = await run(command);
		expect(result).toMatchObject({ block: true, reason: expect.stringContaining(reason) });
	});

	test("allows git worktree list", async () => {
		expect(await run("git worktree list")).toEqual(allowed);
	});

	test.each([
		"git push -u origin agent/task",
		"gh pr create --title t --body b",
		"herdr agent prompt w-other 'do it'",
		"herdr worktree create --branch agent/x",
		"git rebase origin/main",
		"git pull --rebase origin main",
		"git branch -D agent/old",
		"timeout 60 git push",
		"echo 1 | xargs -n 1 gh pr create --fill",
		"bash -c 'git push'",
		"find . -name x -exec git push \\;",
		"watch -n 5 git push",
	])("blocks a worker from: %s", async (command) => {
		const { result, questions } = await run(command, { systemPrompt: "Base prompt.\nYou are a worker agent. Follow worker.md." });
		expect(questions).toEqual([]);
		expect(result).toMatchObject({ block: true, reason: expect.stringContaining("Workers commit on their own branch only") });
	});

	test.each(["git push -u origin agent/task", "gh pr create --title t --body b"])("lets a session without the worker prompt run: %s", async (command) => {
		expect(await run(command)).toEqual(allowed);
	});
});

describe("package managers", () => {
	test.each(["npm install", "npx tsx script.ts", "npm create vite@latest app", "npm init -y", "yarn", "yarn add left-pad"])(
		"blocks npm and yarn without their lockfile: %s",
		async (command) => {
			const { result } = await run(command);
			expect(result).toMatchObject({ block: true, reason: expect.stringContaining("Use pnpm") });
		},
	);

	test.each([
		["npm ci", () => npmProject],
		["npm run build", () => npmPackage],
		["yarn --version", () => main],
	])("allows %s", async (command, cwd) => {
		expect(await run(command, { cwd: cwd() })).toEqual(allowed);
	});
});
