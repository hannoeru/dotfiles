import type {
	BashToolCallEvent,
	ExtensionAPI,
	ExtensionContext,
	ExtensionHandler,
	ToolCallEvent,
	ToolCallEventResult,
} from "@earendil-works/pi-coding-agent";
import { expect, test } from "vitest";
import gitInterceptor from "../extensions/git-interceptor.ts";

function createExtension() {
	let handler: ExtensionHandler<ToolCallEvent, ToolCallEventResult> | undefined;
	const pi = {
		on: (event: string, eventHandler: ExtensionHandler<ToolCallEvent, ToolCallEventResult>) => {
			if (event === "tool_call") handler = eventHandler;
		},
	} as unknown as ExtensionAPI;

	gitInterceptor(pi);

	return async (command: string) => {
		expect(handler).toBeDefined();
		const event = {
			type: "tool_call",
			toolCallId: "tool-123",
			toolName: "bash",
			input: { command },
		} as BashToolCallEvent;
		const result = await handler?.(event, {} as ExtensionContext);
		return { command: event.input.command, result };
	};
}

test("sets non-interactive editor variables for Git commands", async () => {
	const run = createExtension();

	const { command, result } = await run("git commit");

	expect(command).toBe(
		"export GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no\ngit commit",
	);
	expect(result).toBeUndefined();
});

test.each(["git commit --no-verify", "git commit -n"])("blocks Git hook bypass: %s", async (input) => {
	const run = createExtension();

	const { command, result } = await run(input);

	expect(command).toBe(input);
	expect(result).toEqual({
		block: true,
		reason: expect.stringContaining("Git hook bypass flags are not allowed"),
	});
});

test("allows -n for Git commands that do not use it to bypass hooks", async () => {
	const run = createExtension();

	const { command, result } = await run("git log -n 1");

	expect(command).toBe(
		"export GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no\ngit log -n 1",
	);
	expect(result).toBeUndefined();
});

test("leaves commands without Git unchanged", async () => {
	const run = createExtension();

	const { command, result } = await run("pnpm test");

	expect(command).toBe("pnpm test");
	expect(result).toBeUndefined();
});
