import type { ExtensionAPI, ExtensionCommandContext } from "@earendil-works/pi-coding-agent";
import { expect, test, vi } from "vitest";
import handoff from "../extensions/handoff.ts";

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
