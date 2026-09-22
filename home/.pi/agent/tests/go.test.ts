import type { ContextEvent, ExtensionAPI, ExtensionContext, ExtensionHandler } from "@earendil-works/pi-coding-agent";
import { expect, test } from "vitest";
import goExtension from "../extensions/go.ts";

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
			expect(goHandler).toBeDefined();
			goHandler?.();
		},
		context(messages: unknown[]) {
			expect(contextHandler).toBeDefined();
			return contextHandler?.({ type: "context", messages } as ContextEvent, {} as ExtensionContext);
		},
		sendCall: () => sendCall,
	};
}

test("go command sends a hidden, turn-triggering marker", () => {
	const extension = createExtension();
	extension.runGo();

	expect(extension.sendCall()).toEqual({
		message: { customType: "go:resume", content: [], display: false },
		options: { triggerTurn: true, deliverAs: "followUp" },
	});
});

test("context handler removes only the resume marker", async () => {
	const extension = createExtension();
	const marker = { role: "custom", customType: "go:resume", content: [], display: false };
	const user = { role: "user", content: [{ type: "text", text: "hello" }] };

	const result = await extension.context([user, marker]);

	expect(result).toEqual({ messages: [user] });
});

test("context handler leaves messages unchanged when no marker is present", async () => {
	const extension = createExtension();
	const user = { role: "user", content: [{ type: "text", text: "hello" }] };

	const result = await extension.context([user]);

	expect(result).toBeUndefined();
});
