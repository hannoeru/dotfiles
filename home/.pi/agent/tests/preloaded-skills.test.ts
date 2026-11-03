import { mkdtemp, mkdir, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import {
	DefaultResourceLoader,
	ExtensionRunner,
	ModelRegistry,
	ModelRuntime,
	SessionManager,
	SettingsManager,
} from "@earendil-works/pi-coding-agent";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import preloadedSkills from "../extensions/preloaded-skills.ts";

const instructions = "# Poteto mode\nUse Poteto Mode by default.\n\n# Herdr\nApply only when HERDR_ENV=1.";
let root: string;
let agentDir: string;
let cwd: string;

beforeEach(async () => {
	root = await mkdtemp(join(tmpdir(), "pi-preloaded-skills-"));
	agentDir = join(root, "agent");
	cwd = join(root, "project");
	await mkdir(agentDir);
	await mkdir(join(cwd, ".pi"), { recursive: true });
	await writeFile(join(agentDir, "APPEND_SYSTEM.md"), `${instructions}\n`);
	await writeFile(join(agentDir, "AGENTS.md"), await readFile(new URL("../AGENTS.md", import.meta.url), "utf8"));
	vi.stubEnv("PI_CODING_AGENT_DIR", agentDir);
});

afterEach(async () => {
	vi.unstubAllEnvs();
	await rm(root, { recursive: true, force: true });
});

test.each([
	{ name: "no project append", projectAppend: "", trusted: false },
	{ name: "a trusted project append", projectAppend: "Keep the project instructions.", trusted: true },
	{ name: "an untrusted project append", projectAppend: "Ignore these untrusted instructions.", trusted: false },
])("preserves preloads with $name", async ({ projectAppend, trusted }) => {
	if (projectAppend) await writeFile(join(cwd, ".pi", "APPEND_SYSTEM.md"), projectAppend);
	const settingsManager = SettingsManager.inMemory({}, { projectTrusted: trusted });
	const loader = new DefaultResourceLoader({
		cwd,
		agentDir,
		settingsManager,
		noExtensions: true,
		noSkills: true,
		noPromptTemplates: true,
		noThemes: true,
		extensionFactories: [preloadedSkills],
	});
	await loader.reload();
	const loaded = loader.getExtensions();
	expect(loaded.errors).toEqual([]);
	const runtime = await ModelRuntime.create({ authPath: join(root, "auth.json"), modelsPath: null, refreshOnCreate: false });
	const runner = new ExtensionRunner(loaded.extensions, loaded.runtime, cwd, SessionManager.inMemory(cwd), new ModelRegistry(runtime));
	const options = {
		cwd,
		appendSystemPrompt: [...loader.getAppendSystemPrompt(), "Keep the CLI instructions."].join("\n\n"),
		contextFiles: loader.getAgentsFiles().agentsFiles,
		sections: { other_extension: "Keep the other extension instructions." },
	};

	const first = await runner.emitBeforeAgentStart({ messageType: "user", prompt: "First request" }, options);
	const second = await runner.emitBeforeAgentStart({ messageType: "user", prompt: "Next request" }, first.systemPromptOptions);

	for (const { systemPromptOptions } of [first, second]) {
		expect(systemPromptOptions.sections.preloaded_skills).toBe(instructions);
		expect(systemPromptOptions.appendSystemPrompt).not.toContain(instructions);
		expect(systemPromptOptions.appendSystemPrompt).toContain("Keep the CLI instructions.");
		expect(systemPromptOptions.sections.other_extension).toBe("Keep the other extension instructions.");
		if (projectAppend) expect(systemPromptOptions.appendSystemPrompt.includes(projectAppend)).toBe(trusted);
		expect(systemPromptOptions.contextFiles.some(({ content }) => content.includes("Use the GitHub CLI (`gh`)"))).toBe(true);
	}
});
