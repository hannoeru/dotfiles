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

test.each([
	"git commit --no-verify",
	"git commit -n",
	"git commit -nm x",
	"git commit -an",
	"git commit -m x -n",
	'git commit "-n"',
	"git -C repo commit -n",
	"git -c core.hooksPath=/tmp/empty commit -m x",
	"git -c CORE.HOOKSPATH=/tmp/empty commit -m x",
	"git push --no-verify",
	"cd repo && git commit -n",
	"echo ok; GIT_AUTHOR_NAME=x git commit -n",
	"env FOO=1 git commit -n",
	"/usr/bin/git commit -n",
	"if git commit -n; then echo ok; fi",
	"echo $(git commit -n)",
	"git commit -m x 2>&1 -n",
	"cat <<EOF\ntext\nEOF\ngit commit -n",
])("blocks Git hook bypass: %s", async (input) => {
	const run = createExtension();

	const { command, result } = await run(input);

	expect(command).toBe(input);
	expect(result).toEqual({
		block: true,
		reason: expect.stringContaining("Git hook bypass flags are not allowed"),
	});
});

test.each([
	"git log -n 1",
	"git push -n",
	"grep -r -e --no-verify git-notes",
	"grep git commit -n",
	"echo 'git commit --no-verify'",
	"echo hi # git commit -n",
	"cat <<EOF\ngit commit --no-verify\nEOF",
	"cat <<'EOF'\ngit commit -n\nEOF\necho git",
	"cat <<-EOF\n\tgit commit -n\n\tEOF",
	'git commit -m "document -n flag"',
	'git commit -m "document --no-verify"',
	"git commit -m --no-verify",
	"git commit -mn",
	"git commit -uno -m x",
	"git commit -- -n",
	'git commit -m "a; git commit -n"',
	'git -c user.name="--no-verify" log',
])("allows text that does not bypass hooks: %s", async (input) => {
	const run = createExtension();

	const { command, result } = await run(input);

	expect(command).toBe(`export GIT_EDITOR=true GIT_SEQUENCE_EDITOR=true GIT_MERGE_AUTOEDIT=no\n${input}`);
	expect(result).toBeUndefined();
});

test("leaves commands without Git unchanged", async () => {
	const run = createExtension();

	const { command, result } = await run("pnpm test");

	expect(command).toBe("pnpm test");
	expect(result).toBeUndefined();
});
