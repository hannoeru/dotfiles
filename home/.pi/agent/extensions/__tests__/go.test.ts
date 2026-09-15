import assert from "node:assert/strict";
import { test } from "node:test";
import type { ContextEvent, ExtensionAPI, ExtensionContext, ExtensionHandler } from "@earendil-works/pi-coding-agent";
import goExtension from "../go.ts";

interface ContextFilterResult {
	messages?: unknown[];
}

interface SendMessageCall {
	message: { customType: string; content: unknown; display: boolean };
	options: { triggerTurn: boolean; deliverAs: string };
}

function createExtension() {
	let contextHandler: ExtensionHandler<ContextEvent, ContextFilterResult> | undefined;
	let goHandler: (() => void) | undefined;
	let sendCall: SendMessageCall | undefined;

	const pi = {
		on: (event: string, handler: ExtensionHandler<ContextEvent, ContextFilterResult>) => {
			if (event === "context") contextHandler = handler;
		},
		registerCommand: (_name: string, options: { handler: () => void }) => {
			goHandler = options.handler;
		},
		sendMessage: (
			message: { customType: string; content: unknown; display: boolean },
			options: { triggerTurn: boolean; deliverAs: string },
		) => {
			sendCall = { message, options };
		},
	} as unknown as ExtensionAPI;

	goExtension(pi);

	return {
		runGo() {
			assert.ok(goHandler, "the extension must register a go command");
			goHandler();
		},
		context(messages: unknown[]) {
			assert.ok(contextHandler, "the extension must register a context handler");
			return contextHandler({ type: "context", messages } as ContextEvent, {} as ExtensionContext);
		},
		sendCall: () => sendCall,
	};
}

test("go command sends a hidden, turn-triggering marker", () => {
	const extension = createExtension();
	extension.runGo();

	const call = extension.sendCall();
	assert.ok(call, "the command must call sendMessage");
	assert.equal(call.message.customType, "go:resume");
	assert.deepEqual(call.message.content, []);
	assert.equal(call.message.display, false);
	assert.deepEqual(call.options, { triggerTurn: true, deliverAs: "followUp" });
});

test("context handler removes only the resume marker", async () => {
	const extension = createExtension();

	const marker = { role: "custom", customType: "go:resume", content: [], display: false };
	const user = { role: "user", content: [{ type: "text", text: "hello" }] };
	const result = await extension.context([user, marker]);

	assert.ok(result, "the handler must filter the marker");
	assert.deepEqual(result.messages, [user]);
});

test("context handler leaves messages unchanged when no marker is present", async () => {
	const extension = createExtension();

	const user = { role: "user", content: [{ type: "text", text: "hello" }] };
	const result = await extension.context([user]);

	assert.equal(result, undefined);
});