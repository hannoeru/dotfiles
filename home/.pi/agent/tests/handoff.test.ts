import { complete } from "@earendil-works/pi-ai/compat";
import {
	type BorderedLoader,
	type ExtensionAPI,
	type ExtensionCommandContext,
	initTheme,
} from "@earendil-works/pi-coding-agent";
import { beforeEach, expect, test, vi } from "vitest";
import handoff from "../extensions/handoff.ts";

vi.mock("@earendil-works/pi-ai/compat", () => ({ complete: vi.fn() }));

const completeMock = vi.mocked(complete);

beforeEach(() => {
	initTheme("dark");
	completeMock.mockReset();
});

interface HandoffOptions {
	description: string;
	handler: (args: string, context: ExtensionCommandContext) => Promise<void>;
}

function createExtension() {
	let options: HandoffOptions | undefined;
	const pi = {
		registerCommand: (name: string, commandOptions: HandoffOptions) => {
			expect(name).toBe("handoff");
			options = commandOptions;
		},
	} as unknown as ExtensionAPI;

	handoff(pi);
	expect(options).toBeDefined();
	return options!;
}

function createContext({ hasUI = true, hasModel = true, hasMessages = true } = {}) {
	const notify = vi.fn();
	const context = {
		hasUI,
		model: hasModel ? {} : undefined,
		ui: { notify },
		sessionManager: {
			getBranch: () => (hasMessages ? [{ type: "message", message: { role: "user", content: "hello" } }] : []),
		},
	} as unknown as ExtensionCommandContext;
	return { context, notify };
}

test("registers the handoff command", () => {
	const options = createExtension();

	expect(options.description).toBe("Transfer context to a new focused session");
});

test.each([
	{
		name: "non-interactive sessions",
		args: "continue the task",
		contextOptions: { hasUI: false },
		message: "handoff requires interactive mode",
	},
	{
		name: "sessions without a model",
		args: "continue the task",
		contextOptions: { hasModel: false },
		message: "No model selected",
	},
	{
		name: "an empty goal",
		args: "   ",
		contextOptions: {},
		message: "Usage: /handoff <goal for new thread>",
	},
	{
		name: "sessions without messages",
		args: "continue the task",
		contextOptions: { hasMessages: false },
		message: "No conversation to hand off",
	},
])("rejects $name", async ({ args, contextOptions, message }) => {
	const options = createExtension();
	const { context, notify } = createContext(contextOptions);

	await options.handler(args, context);

	expect(notify).toHaveBeenCalledWith(message, "error");
});

function createGenerationContext(onLoader: (loader: BorderedLoader) => void = () => {}) {
	const notify = vi.fn();
	const editor = vi.fn(async () => undefined);
	const custom = (factory: (...args: unknown[]) => BorderedLoader) =>
		new Promise((resolve) => {
			const tui = { requestRender: () => {} };
			const theme = { fg: (_color: string, text: string) => text };
			let loader: BorderedLoader | undefined;
			loader = factory(tui, theme, {}, (result: unknown) => {
				loader?.dispose();
				resolve(result);
			});
			onLoader(loader);
		});
	const context = {
		hasUI: true,
		model: { provider: "test" },
		ui: { notify, editor, custom },
		modelRegistry: { getApiKeyAndHeaders: async () => ({ ok: true, apiKey: "key" }) },
		sessionManager: {
			getBranch: () => [{ type: "message", message: { role: "user", content: "hello", timestamp: 0 } }],
			getSessionFile: () => "session.jsonl",
		},
	} as unknown as ExtensionCommandContext;
	return { context, notify, editor };
}

function response(stopReason: string, text: string, errorMessage?: string) {
	return { stopReason, errorMessage, content: [{ type: "text", text }] } as unknown as Awaited<
		ReturnType<typeof complete>
	>;
}

test.each([
	{
		name: "a thrown generation error",
		generate: () => Promise.reject(new Error("network down")),
		message: "Handoff failed: network down",
	},
	{
		name: "an error stop reason",
		generate: async () => response("error", "", "rate limited"),
		message: "Handoff failed: rate limited",
	},
	{
		name: "an error stop reason without a message",
		generate: async () => response("error", "partial text"),
		message: "Handoff failed: The model returned an error",
	},
	{
		name: "an empty result",
		generate: async () => response("stop", " \n "),
		message: "Handoff failed: The model returned an empty prompt",
	},
])("shows an error and opens no editor for $name", async ({ generate, message }) => {
	completeMock.mockImplementation(generate);
	const { context, notify, editor } = createGenerationContext();

	await createExtension().handler("continue the task", context);

	expect(notify.mock.calls).toEqual([[message, "error"]]);
	expect(editor).not.toHaveBeenCalled();
});

test("shows Cancelled when the model reports an abort", async () => {
	completeMock.mockResolvedValue(response("aborted", ""));
	const { context, notify, editor } = createGenerationContext();

	await createExtension().handler("continue the task", context);

	expect(notify.mock.calls).toEqual([["Cancelled", "info"]]);
	expect(editor).not.toHaveBeenCalled();
});

test("shows Cancelled when the user aborts and generation then rejects", async () => {
	let rejectGeneration: (error: Error) => void = () => {};
	const generationStarted = new Promise<void>((started) => {
		completeMock.mockImplementation(
			() =>
				new Promise((_resolve, reject) => {
					rejectGeneration = reject;
					started();
				}),
		);
	});
	const { context, notify, editor } = createGenerationContext((loader) => {
		void generationStarted.then(() => {
			loader.handleInput("\x1b");
			rejectGeneration(new Error("Request was aborted"));
		});
	});

	await createExtension().handler("continue the task", context);

	expect(notify.mock.calls).toEqual([["Cancelled", "info"]]);
	expect(editor).not.toHaveBeenCalled();
});

test("opens the editor with the generated prompt", async () => {
	completeMock.mockResolvedValue(response("stop", "## Task"));
	const { context, notify, editor } = createGenerationContext();

	await createExtension().handler("continue the task", context);

	expect(editor).toHaveBeenCalledWith("Edit handoff prompt", "## Task");
	expect(notify.mock.calls).toEqual([["Cancelled", "info"]]);
});
