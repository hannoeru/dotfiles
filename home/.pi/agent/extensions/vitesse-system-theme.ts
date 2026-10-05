/**
 * Sync pi with macOS system appearance using custom Vitesse themes.
 *
 * Requires the Vitesse themes in ~/.pi/agent/themes.
 */

import { execFile } from "node:child_process";
import { promisify } from "node:util";
import type {
	ExtensionAPI,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const execFileAsync = promisify(execFile);

const DARK_THEME = "vitesse-dark";
const LIGHT_THEME = "vitesse-light";
const POLL_INTERVAL_MS = 2000;

async function isMacDarkMode(): Promise<boolean> {
	try {
		const { stdout } = await execFileAsync("osascript", [
			"-e",
			'tell application "System Events" to tell appearance preferences to return dark mode',
		]);
		return stdout.trim() === "true";
	} catch {
		return false;
	}
}

async function systemThemeName(): Promise<string> {
	return (await isMacDarkMode()) ? DARK_THEME : LIGHT_THEME;
}

export default function (pi: ExtensionAPI) {
	let intervalId: ReturnType<typeof setInterval> | null = null;
	let currentTheme: string | null = null;
	let checking = false;

	async function applySystemTheme(
		ctx: ExtensionContext,
		notifyOnError = false,
	) {
		if (!ctx.hasUI) return;
		if (checking) return;

		checking = true;
		try {
			const nextTheme = await systemThemeName();
			if (nextTheme === currentTheme) return;

			const result = ctx.ui.setTheme(nextTheme);
			if (result.success) {
				currentTheme = nextTheme;
			} else if (notifyOnError) {
				ctx.ui.notify(`Vitesse system theme failed: ${result.error}`, "error");
			}
		} finally {
			checking = false;
		}
	}

	pi.on("session_start", async (_event, ctx) => {
		if (process.platform !== "darwin") return;
		if (intervalId) clearInterval(intervalId);
		currentTheme = null;

		await applySystemTheme(ctx, true);

		intervalId = setInterval(() => {
			void applySystemTheme(ctx);
		}, POLL_INTERVAL_MS);
	});

	pi.on("session_shutdown", () => {
		if (intervalId) {
			clearInterval(intervalId);
			intervalId = null;
		}
		currentTheme = null;
		checking = false;
	});
}
