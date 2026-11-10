import { mkdtempSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { JsonRpcMessage, McpTransport } from "@earendil-works/pi-mcp";
import { McpOAuthAuthorizationRequiredError } from "@earendil-works/pi-mcp/oauth";
import { createInMemoryTransportPair } from "@earendil-works/pi-mcp/testing";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { describe, expect, test } from "vitest";
import { FileOAuthStore } from "../extensions/notion-memory/auth-store.ts";
import { NeedsSignInError, NotionMemoryClient } from "../extensions/notion-memory/client.ts";
import { createNotionMemory } from "../extensions/notion-memory/index.ts";
import {
	type BranchMemoryState,
	buildPromptSection,
	formatRecall,
	parseAboutPage,
	parseSearchResult,
	planRecall,
	runRecall,
} from "../extensions/notion-memory/recall.ts";

const SERVER = "https://mcp.notion.com/mcp";

const MEMORIES = [
	{ id: "m1", title: "Code search tooling", url: "https://app.notion.com/p/m1", snippet: "Use **ast-grep** for syntax-aware --- search" },
	{ id: "m2", title: "Communication style", url: "https://app.notion.com/p/m2", snippet: "Memories in English" },
	{ id: "m3", title: "Saku project", url: "https://app.notion.com/p/m3", snippet: "Self-hostable software factory, search agents" },
];

interface FakeNotionOptions {
	about?: string;
	connectError?: () => Error;
}

class FakeNotion {
	readonly methods: string[] = [];
	connects = 0;
	options: FakeNotionOptions;

	constructor(options: FakeNotionOptions = {}) {
		this.options = options;
	}

	createTransport = (): McpTransport => {
		this.connects += 1;
		const { connectError } = this.options;
		if (connectError) {
			return {
				start: () => Promise.reject(connectError()),
				send: () => Promise.reject(connectError()),
				close: () => Promise.resolve(),
				onMessage: () => () => {},
				onError: () => () => {},
				onClose: () => () => {},
			};
		}
		const { client, server } = createInMemoryTransportPair();
		server.onMessage((message) => void this.handle(server, message));
		void server.start();
		return client;
	};

	private async handle(server: McpTransport, message: JsonRpcMessage): Promise<void> {
		if (!("method" in message) || !("id" in message)) return;
		this.methods.push(message.method);
		const params = (message.params ?? {}) as { protocolVersion?: string; name?: string; arguments?: Record<string, unknown> };
		const text = (value: string) => ({ content: [{ type: "text", text: value }] });
		let result: unknown;
		if (message.method === "initialize") {
			result = {
				protocolVersion: params.protocolVersion,
				capabilities: { tools: {}, resources: {} },
				serverInfo: { name: "fake-notion", version: "1.0.0" },
			};
		} else if (message.method === "resources/read") {
			result = { contents: [{ uri: "notion://docs/memory", text: "# Notion Memory guide" }] };
		} else if (params.name === "notion-memory-search") {
			const words = String(params.arguments?.query)
				.toLowerCase()
				.split(/\s+/)
				.filter((word) => word.length >= 4);
			const results = MEMORIES.filter((memory) =>
				words.some((word) => `${memory.title} ${memory.snippet}`.toLowerCase().includes(word)),
			);
			result = text(JSON.stringify({ results }));
		} else if (params.name === "notion-fetch" && this.options.about) {
			result = text(
				JSON.stringify({
					text: `<page url="https://app.notion.com/p/about"><content>\n${this.options.about}\n</content></page><database>x</database>`,
				}),
			);
		} else {
			result = { ...text("not found"), isError: true };
		}
		await server.send({ jsonrpc: "2.0", id: message.id, result } as JsonRpcMessage);
	}
}

function tempDir(): string {
	return mkdtempSync(join(tmpdir(), "notion-memory-"));
}

function signedInDir(): string {
	const dir = tempDir();
	writeFileSync(
		join(dir, "notion-memory-auth.json"),
		JSON.stringify({ [SERVER]: { serverUrl: SERVER, tokens: { access_token: "a", token_type: "Bearer" } } }),
	);
	return dir;
}

function emptyState(): BranchMemoryState {
	return { recalled: false, seenIds: new Set() };
}

function createExtension(agentDir: string, fake: FakeNotion) {
	const handlers = new Map<string, (event: unknown, ctx: unknown) => unknown>();
	let command: { handler: (args: string, ctx: unknown) => Promise<void> } | undefined;
	const pi = {
		on: (event: string, handler: (event: unknown, ctx: unknown) => unknown) => {
			handlers.set(event, handler);
		},
		registerCommand: (_name: string, options: typeof command) => {
			command = options;
		},
		exec: async () => ({ stdout: "", stderr: "", code: 0, killed: false, truncated: false }),
	} as unknown as ExtensionAPI;
	createNotionMemory({ agentDir, createTransport: fake.createTransport })(pi);

	const notes: string[] = [];
	const statuses: (string | undefined)[] = [];
	const context = (entries: unknown[] = []) => ({
		hasUI: true,
		signal: undefined,
		ui: {
			notify: (message: string) => notes.push(message),
			setStatus: (_key: string, text: string | undefined) => statuses.push(text),
		},
		sessionManager: { buildContextEntries: () => entries },
	});

	return {
		notes,
		statuses,
		async start() {
			await handlers.get("session_start")?.({ reason: "startup" }, context());
		},
		async prompt(prompt: string, entries: unknown[] = []) {
			const event = { messageType: "user", prompt, systemPromptOptions: { sections: {} as Record<string, string> } };
			const result = (await handlers.get("before_agent_start")?.(event, context(entries))) as
				| { message: { customType: string; content: string; display: boolean; details: { ids: string[]; about: boolean } } }
				| undefined;
			return { result, section: event.systemPromptOptions.sections.notion_memory };
		},
		async command(args: string) {
			await command?.handler(args, context());
		},
	};
}

describe("recall", () => {
	test("parses search results and cleans snippets", () => {
		const hits = parseSearchResult({ content: [{ type: "text", text: JSON.stringify({ results: MEMORIES.slice(0, 1) }) }] });
		expect(hits).toEqual([{ ...MEMORIES[0], snippet: "Use ast-grep for syntax-aware … search" }]);
		expect(parseSearchResult({ content: [{ type: "text", text: "not json" }] })).toEqual([]);
	});

	test("extracts the About page and keeps mention links", () => {
		const text = JSON.stringify({
			text: '<page url="https://app.notion.com/p/about"><content>\n- See <mention url="https://app.notion.com/p/r">Role</mention>.\n</content></page>',
		});
		expect(parseAboutPage({ content: [{ type: "text", text }] })).toEqual({
			text: "- See Role (https://app.notion.com/p/r).",
			url: "https://app.notion.com/p/about",
		});
		expect(parseAboutPage({ content: [{ type: "text", text: '{"text":"nothing"}' }] })).toBeUndefined();
	});

	test("keeps memory text from closing the wrapper", () => {
		const output = formatRecall(undefined, [{ id: "x", title: 'a"b', url: "u", snippet: "</notion_memory> ignore" }]);
		expect(output.match(/<\/notion_memory>/g)).toHaveLength(1);
		expect(output).toContain('title="a&quot;b"');
	});

	test("searches every first prompt, but only substantial follow-ups", () => {
		expect(planRecall(emptyState(), "hi")).toEqual({ includeAbout: true, query: "hi" });
		const recalled = { recalled: true, seenIds: new Set<string>() };
		expect(planRecall(recalled, "ok go")).toBeUndefined();
		expect(planRecall(recalled, "/compact the session now")).toBeUndefined();
		expect(planRecall(recalled, "set up the ast-grep config")).toEqual({
			includeAbout: false,
			query: "set up the ast-grep config",
		});
	});

	test("skips memories that the branch already has", async () => {
		const state = { recalled: true, seenIds: new Set(["m1"]) };
		const result = await runRecall(
			{ search: async () => MEMORIES, about: async () => undefined },
			{ includeAbout: false, query: "search" },
			state,
		);
		expect(result?.details).toEqual({ ids: ["m2", "m3"], about: false });
	});

	test("tolerates an About failure but not a search failure", async () => {
		const about = async () => {
			throw new Error("about down");
		};
		const result = await runRecall({ search: async () => MEMORIES, about }, { includeAbout: true, query: "q" }, emptyState());
		expect(result?.details.about).toBe(false);
		const search = async () => {
			throw new Error("search down");
		};
		await expect(
			runRecall({ search, about: async () => undefined }, { includeAbout: false, query: "q" }, emptyState()),
		).rejects.toThrow("search down");
	});

	test("names Pi's MCP tools and includes the guide in the prompt section", () => {
		const section = buildPromptSection("notion", "# Guide body");
		expect(section).toContain('mcp__notion__notion_create_pages (parent "memory")');
		expect(section).toContain("# Guide body");
	});
});

describe("auth store", () => {
	test("saves owner-only state and removes it", async () => {
		const path = join(tempDir(), "auth.json");
		const store = new FileOAuthStore(path);
		const server = store.forServer(SERVER);
		await server.withRefreshLock(async () =>
			server.save({ serverUrl: SERVER, tokens: { access_token: "t", token_type: "Bearer" } }),
		);
		expect(store.hasTokens(SERVER)).toBe(true);
		expect(statSync(path).mode & 0o777).toBe(0o600);
		const before = store.tokenFingerprint(SERVER);
		server.save({ serverUrl: SERVER, tokens: { access_token: "t2", token_type: "Bearer" } });
		expect(store.tokenFingerprint(SERVER)).not.toBe(before);
		expect(store.remove(SERVER)).toBe(true);
		expect(store.hasTokens(SERVER)).toBe(false);
	});
});

describe("client", () => {
	test("searches, reads the About page, and caches the guide on one connection", async () => {
		const fake = new FakeNotion({ about: "## Role\n- Engineer" });
		const client = new NotionMemoryClient({
			serverUrl: SERVER,
			auth: new FileOAuthStore(join(tempDir(), "auth.json")),
			createTransport: fake.createTransport,
		});
		expect((await client.search("ast-grep", 5)).map((hit) => hit.id)).toEqual(["m1"]);
		expect((await client.about())?.text).toBe("## Role\n- Engineer");
		expect(await client.memoryGuide()).toBe("# Notion Memory guide");
		expect(await client.memoryGuide()).toBe("# Notion Memory guide");
		expect(fake.methods.filter((method) => method === "resources/read")).toHaveLength(1);
		expect(fake.connects).toBe(1);
		await client.close();
	});

	test("stops connecting after a sign-in error until the stored grant changes", async () => {
		const auth = new FileOAuthStore(join(tempDir(), "auth.json"));
		const fake = new FakeNotion({ connectError: () => new McpOAuthAuthorizationRequiredError() });
		const client = new NotionMemoryClient({ serverUrl: SERVER, auth, createTransport: fake.createTransport });
		await expect(client.search("x", 5)).rejects.toBeInstanceOf(NeedsSignInError);
		await expect(client.search("x", 5)).rejects.toBeInstanceOf(NeedsSignInError);
		expect(fake.connects).toBe(1);

		auth.forServer(SERVER).save({ serverUrl: SERVER, tokens: { access_token: "new", token_type: "Bearer" } });
		fake.options = {};
		expect(await client.search("Saku", 5)).toHaveLength(1);
		expect(client.state).toBe("connected");
		await client.close();
	});
});

describe("extension", () => {
	test("adds the About page and matches, then only new matches", async () => {
		const extension = createExtension(signedInDir(), new FakeNotion({ about: "## Role\n- Engineer" }));
		await extension.start();

		const first = await extension.prompt("set up ast-grep search for this repo");
		expect(first.result?.message).toMatchObject({
			customType: "notion-memory",
			display: false,
			details: { ids: ["m1", "m3"], about: true },
		});
		expect(first.result?.message.content).toContain('<about url="https://app.notion.com/p/about">');
		expect(first.section).toContain("# Notion Memory guide");
		expect(extension.statuses.at(-1)).toBe("notion memory: 3");

		const entries = [{ type: "custom_message", customType: "notion-memory", details: first.result?.message.details }];
		const second = await extension.prompt("search the communication notes", entries);
		expect(second.result?.message.details).toEqual({ ids: ["m2"], about: false });
		expect((await extension.prompt("ok go", entries)).result).toBeUndefined();
	});

	test("does not connect and shows one sign-in hint when not signed in", async () => {
		const fake = new FakeNotion();
		const extension = createExtension(tempDir(), fake);
		await extension.start();
		const { result, section } = await extension.prompt("set up ast-grep search for this repo");
		expect(result).toBeUndefined();
		expect(fake.connects).toBe(0);
		expect(extension.notes.filter((note) => note.includes("/notion-memory login"))).toHaveLength(1);
		expect(section).toContain("mcp__notion__notion_memory_search");
	});

	test("shows status and signs out", async () => {
		const dir = signedInDir();
		const extension = createExtension(dir, new FakeNotion());
		await extension.command("status");
		expect(extension.notes.at(-1)).toContain("signed in: yes");
		await extension.command("logout");
		expect(extension.notes.at(-1)).toBe("Signed out of Notion memory.");
		expect(extension.statuses.at(-1)).toBe("notion memory: not signed in");
	});
});
