import { existsSync, mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { afterEach, beforeEach, expect, test, vi } from "vitest";
import rexAgentSessionExtension from "../extensions/rex-agent-session.ts";

let stateHome: string;

beforeEach(() => {
	stateHome = mkdtempSync(join(tmpdir(), "rex-agent-session-"));
	vi.stubEnv("XDG_STATE_HOME", stateHome);
	vi.stubEnv("REX_BLOCK", "block:0001");
	vi.stubEnv("HERDR_ENV", "");
});

afterEach(() => {
	vi.unstubAllEnvs();
});

function startSession(ctx: { mode: string; sessionFile: string | undefined; cwd: string }) {
	let handler: ((event: unknown, ctx: ExtensionContext) => void) | undefined;
	const pi = {
		on: (event: string, fn: (event: unknown, ctx: ExtensionContext) => void) => {
			if (event === "session_start") handler = fn;
		},
	} as unknown as ExtensionAPI;

	rexAgentSessionExtension(pi);
	handler?.({ type: "session_start" }, {
		mode: ctx.mode,
		cwd: ctx.cwd,
		sessionManager: { getSessionFile: () => ctx.sessionFile },
	} as unknown as ExtensionContext);
}

const recordPath = () => join(stateHome, "rex-agent-sessions", "0001");

test("a TUI session in a Rex terminal records the agent, session file, cwd, and process for its block", () => {
	startSession({ mode: "tui", sessionFile: "/sessions/a.jsonl", cwd: "/work" });

	expect(readFileSync(recordPath(), "utf8")).toBe(`pi\n/sessions/a.jsonl\n/work\n${process.pid}\n`);
});

test("a later session in the same block replaces the record", () => {
	startSession({ mode: "tui", sessionFile: "/sessions/a.jsonl", cwd: "/work" });
	startSession({ mode: "tui", sessionFile: "/sessions/b.jsonl", cwd: "/work" });

	expect(readFileSync(recordPath(), "utf8")).toBe(`pi\n/sessions/b.jsonl\n/work\n${process.pid}\n`);
});

test("headless modes and sessions without a file record nothing", () => {
	startSession({ mode: "print", sessionFile: "/sessions/a.jsonl", cwd: "/work" });
	startSession({ mode: "tui", sessionFile: undefined, cwd: "/work" });

	expect(existsSync(recordPath())).toBe(false);
});

test("Pi inside Herdr records nothing, because Herdr resumes its own panes", () => {
	vi.stubEnv("HERDR_ENV", "1");
	startSession({ mode: "tui", sessionFile: "/sessions/a.jsonl", cwd: "/work" });

	expect(existsSync(recordPath())).toBe(false);
});

test("Pi outside Rex records nothing", () => {
	vi.stubEnv("REX_BLOCK", "");
	startSession({ mode: "tui", sessionFile: "/sessions/a.jsonl", cwd: "/work" });

	expect(existsSync(recordPath())).toBe(false);
});
