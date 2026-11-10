import type { BeforeAgentStartEvent, ExtensionAPI, McpServerConfig } from "@earendil-works/pi-coding-agent";
import { expect, test } from "vitest";
import notionMemoryExtension, { NOTION_MEMORY_SECTION } from "../extensions/notion-memory.ts";

function createExtension() {
	const servers = new Map<string, McpServerConfig>();
	let beforeAgentStart: ((event: BeforeAgentStartEvent) => void) | undefined;

	const pi = {
		registerMcpServer: (name: string, config: McpServerConfig) => {
			servers.set(name, config);
		},
		on: (event: string, handler: (event: BeforeAgentStartEvent) => void) => {
			if (event === "before_agent_start") beforeAgentStart = handler;
		},
	} as unknown as ExtensionAPI;

	notionMemoryExtension(pi);

	return {
		servers,
		runBeforeAgentStart(sections: Record<string, string>) {
			expect(beforeAgentStart).toBeDefined();
			beforeAgentStart?.({ systemPromptOptions: { sections } } as unknown as BeforeAgentStartEvent);
			return sections;
		},
	};
}

test("registers Notion's MCP server with the memory tools declared directly", () => {
	const { servers } = createExtension();

	expect(servers.get("notion")).toMatchObject({
		url: "https://mcp.notion.com/mcp",
		toolExposure: { "notion-memory-search": "direct", "notion-fetch": "direct" },
	});
	expect(servers.get("notion")).not.toHaveProperty("exposure");
});

test("adds the memory section and keeps the other sections", () => {
	const sections = createExtension().runBeforeAgentStart({ project: "rules" });

	expect(sections).toEqual({ project: "rules", notion_memory: NOTION_MEMORY_SECTION });
});

test("names only the tools that the server declares directly", () => {
	expect(new Set(NOTION_MEMORY_SECTION.match(/mcp__notion__\w+/g))).toEqual(
		new Set(["mcp__notion__notion_memory_search", "mcp__notion__notion_fetch"]),
	);
});
