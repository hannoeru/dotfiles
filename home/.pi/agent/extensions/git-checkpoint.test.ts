import assert from "node:assert/strict";
import { execFile } from "node:child_process";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
import { afterEach, test } from "node:test";
import type { ExtensionAPI, ExtensionContext, ExtensionHandler, TurnStartEvent } from "@earendil-works/pi-coding-agent";
import gitCheckpoint from "./git-checkpoint.ts";

const execFileAsync = promisify(execFile);
const repositories: string[] = [];

afterEach(async () => {
	await Promise.all(repositories.splice(0).map((directory) => rm(directory, { force: true, recursive: true })));
});

async function git(cwd: string, ...args: string[]): Promise<string> {
	const { stdout } = await execFileAsync("git", args, { cwd });
	return stdout;
}

async function createRepository(): Promise<string> {
	const directory = await mkdtemp(join(tmpdir(), "pi-checkpoint-test-"));
	repositories.push(directory);
	await git(directory, "init", "--quiet");
	await git(directory, "config", "user.email", "test@example.com");
	await git(directory, "config", "user.name", "Test User");
	await git(directory, "config", "commit.gpgsign", "false");
	await writeFile(join(directory, "tracked.txt"), "tracked\n");
	await git(directory, "add", "tracked.txt");
	await git(directory, "commit", "--quiet", "-m", "initial");
	return directory;
}

function createExtension(cwd: string) {
	let turnStart: ExtensionHandler<TurnStartEvent> | undefined;
	const pi = {
		exec: async (command: string, args: string[], options: { cwd?: string } = {}) => {
			try {
				const { stderr, stdout } = await execFileAsync(command, args, { cwd: options.cwd });
				return { code: 0, stderr, stdout };
			} catch (error) {
				const result = error as { code?: number; stderr?: string; stdout?: string };
				return { code: result.code ?? 1, stderr: result.stderr ?? "", stdout: result.stdout ?? "" };
			}
		},
		on: (event: string, handler: ExtensionHandler<TurnStartEvent>) => {
			if (event === "turn_start") turnStart = handler;
		},
		registerCommand: () => {},
	} as unknown as ExtensionAPI;
	gitCheckpoint(pi);

	return async () => {
		assert.ok(turnStart, "the extension must register a turn-start handler");
		await turnStart({ timestamp: Date.now(), turnIndex: 0, type: "turn_start" }, {
			sessionManager: {
				getCwd: () => cwd,
				getLeafEntry: () => ({ id: "entry" }),
			},
		} as ExtensionContext);
	};
}

test("turn-start checkpoints exclude ignored and secret files", async () => {
	const repository = await createRepository();
	await writeFile(join(repository, ".gitignore"), "ignored.txt\n");
	await writeFile(join(repository, ".env"), "TOKEN=secret\n");
	await writeFile(join(repository, "credentials.json"), '{"token":"secret"}\n');
	await mkdir(join(repository, ".aws"));
	await writeFile(join(repository, ".aws", "credentials"), "[default]\naws_secret_access_key = secret\n");
	await writeFile(join(repository, "ignored.txt"), "ignored\n");
	await writeFile(join(repository, "notes.txt"), "safe\n");

	await createExtension(repository)();

	const files = (await git(repository, "ls-tree", "-r", "--name-only", "refs/pi-checkpoint/entry"))
		.trim()
		.split("\n");
	assert.deepEqual(files.sort(), [".gitignore", "notes.txt", "tracked.txt"]);
	assert.equal(await readFile(join(repository, ".env"), "utf8"), "TOKEN=secret\n");
});
