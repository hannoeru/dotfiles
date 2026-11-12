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

type Options = { cwd?: string; hasUI?: boolean; approve?: boolean; systemPrompt?: string };

async function run(command: string, { cwd = main, hasUI = true, approve = false, systemPrompt = "" }: Options = {}) {
	const runner = await runnerFor(cwd);
	runner.bindCore({} as ExtensionActions, { getSystemPrompt: () => systemPrompt } as ExtensionContextActions);
	const questions: string[] = [];
	const confirm = async (_title: string, message: string) => {
		questions.push(message);
		return approve;
	};
	runner.setUIContext(hasUI ? ({ confirm } as unknown as ExtensionUIContext) : undefined);
	const event: BashToolCallEvent = { type: "tool_call", toolCallId: "t", toolName: "bash", input: { command } };
	const result = await runner.emitToolCall(event);
	return { result, questions };
}

const allowed = { result: undefined, questions: [] };

describe("GitHub writes need the human's approval", () => {
	test.each([
		"gh issue edit 123 --add-label bug",
		"gh pr edit 12 --add-label bug",
		"gh pr comment 5369 --body-file /tmp/review.md",
		"gh issue close 294 --comment 'out of scope'",
		"gh pr review 12 --approve",
		"gh gist create notes.md",
		"gh api repos/o/r/issues/1/comments -f body=hi",
		"gh api -X DELETE repos/o/r/labels/bug",
		"gh api -XPOST repos/o/r/issues/1/labels",
		"gh api graphql -f query='mutation { addComment(input: {}) { clientMutationId } }'",
		"gh api graphql --input mutation.json",
		"timeout 30 gh issue close 1",
		"echo 1 | xargs -n 1 gh issue close",
		"bash -c 'gh issue close 1'",
		"find . -name '*.md' -exec gh issue close 1 \\;",
		"watch -n 5 gh issue close 1",
	])("asks before: %s", async (command) => {
		const { result, questions } = await run(command);
		expect(questions[0]).toContain("Draft the text for the human");
		expect(result).toMatchObject({ block: true });
	});

	test("runs the command when the human approves", async () => {
		expect(await run("gh pr comment 1 --body ok", { approve: true })).toEqual({ result: undefined, questions: [expect.any(String)] });
	});

	test("blocks without a UI", async () => {
		const { result, questions } = await run("gh issue close 1", { hasUI: false });
		expect(questions).toEqual([]);
		expect(result).toMatchObject({ block: true, reason: expect.stringContaining("did not approve") });
	});

	test.each([
		"gh pr view 1 --json body",
		"gh api repos/o/r/pulls",
		"gh api graphql -f query='query { viewer { login } }'",
		"gh pr create --title t --body-file b.md",
		"gh pr edit 73 --body-file /tmp/body.md",
		"echo 'gh issue close 1'",
		"bash script.sh",
		"gh workflow run ci.yml",
	])("allows reads and the orchestrator's own PRs: %s", async (command) => {
		expect(await run(command)).toEqual(allowed);
	});
});

describe("Herdr agents", () => {
	test("asks before an agent kind other than Pi", async () => {
		const { questions } = await run("herdr agent start r-x --kind codex --pane w1:p2");
		expect(questions[0]).toContain("Use `--kind codex` only when the human asked for it.");
	});

	test("allows Pi agents", async () => {
		const command = "herdr agent start w-x --kind pi --pane w1:p2 -- --append-system-prompt 'You are a worker agent.'";
		expect(await run(command)).toEqual(allowed);
	});

	test("blocks herdr server stop", async () => {
		const { result, questions } = await run("herdr server stop");
		expect(questions).toEqual([]);
		expect(result).toMatchObject({ block: true, reason: expect.stringContaining("Leave the server running") });
	});

	test.each(["herdr agent send-keys w-x enter", "herdr pane send-text w1:p2 y"])("blocks answers to a dialog: %s", async (command) => {
		const { result, questions } = await run(command);
		expect(questions).toEqual([]);
		expect(result).toMatchObject({ block: true, reason: expect.stringContaining("The human answers its dialogs") });
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

describe("dependencies", () => {
	test("asks before zod and names valibot", async () => {
		const { questions } = await run("pnpm --filter web add -D zod");
		expect(questions[0]).toContain("Use valibot for schemas");
	});

	test.each(["pnpm add valibot", "pnpm install --frozen-lockfile"])("allows %s", async (command) => {
		expect(await run(command)).toEqual(allowed);
	});
});
