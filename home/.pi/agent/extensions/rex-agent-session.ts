import { mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Records the Pi session that runs in a Rex terminal, so the shell in that
 * terminal can resume it after the Rex server restores its sessions.
 * Herdr resumes its own panes, so a Pi inside Herdr is not recorded.
 */
export default function rexAgentSessionExtension(pi: ExtensionAPI): void {
	const block = process.env.REX_BLOCK;
	if (!block || process.env.HERDR_ENV === "1") return;

	const stateDir = join(process.env.XDG_STATE_HOME || join(homedir(), ".local", "state"), "rex-agent-sessions");

	pi.on("session_start", (_event, ctx) => {
		if (ctx.mode !== "tui") return;
		const sessionFile = ctx.sessionManager.getSessionFile();
		if (!sessionFile) return;
		mkdirSync(stateDir, { recursive: true });
		writeFileSync(join(stateDir, block.replace(/^block:/, "")), `pi\n${sessionFile}\n${ctx.cwd}\n`);
	});
}
