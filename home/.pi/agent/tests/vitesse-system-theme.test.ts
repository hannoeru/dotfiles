import type {
	ExtensionAPI,
	ExtensionContext,
	ExtensionHandler,
	SessionShutdownEvent,
	SessionStartEvent,
} from "@earendil-works/pi-coding-agent";
import { afterEach, expect, test, vi } from "vitest";
import vitesseSystemTheme from "../extensions/vitesse-system-theme.ts";

const { execFileAsync } = vi.hoisted(() => ({
	execFileAsync: vi.fn(),
}));

vi.mock("node:util", () => ({
	promisify: () => execFileAsync,
}));

function createExtension() {
	let startHandler: ExtensionHandler<SessionStartEvent> | undefined;
	let shutdownHandler: ExtensionHandler<SessionShutdownEvent> | undefined;

	const pi = {
		on: (event: string, handler: ExtensionHandler<SessionStartEvent | SessionShutdownEvent>) => {
			if (event === "session_start") {
				startHandler = handler as ExtensionHandler<SessionStartEvent>;
			}
			if (event === "session_shutdown") {
				shutdownHandler = handler as ExtensionHandler<SessionShutdownEvent>;
			}
		},
	} as unknown as ExtensionAPI;

	vitesseSystemTheme(pi);

	return {
		start(ctx: ExtensionContext) {
			expect(startHandler).toBeDefined();
			return startHandler?.({ type: "session_start" } as SessionStartEvent, ctx);
		},
		shutdown(ctx: ExtensionContext) {
			expect(shutdownHandler).toBeDefined();
			return shutdownHandler?.({ type: "session_shutdown" } as SessionShutdownEvent, ctx);
		},
	};
}

function createContext() {
	const setTheme = vi.fn(
		(_name: string): { success: true } | { success: false; error: string } => ({
			success: true,
		}),
	);
	const notify = vi.fn();
	const ctx = {
		hasUI: true,
		ui: { setTheme, notify },
	} as unknown as ExtensionContext;

	return { ctx, notify, setTheme };
}

afterEach(() => {
	vi.useRealTimers();
	vi.restoreAllMocks();
	execFileAsync.mockReset();
});

test("follows macOS appearance until the session shuts down", async () => {
	vi.useFakeTimers();
	vi.spyOn(process, "platform", "get").mockReturnValue("darwin");
	execFileAsync
		.mockResolvedValueOnce({ stdout: "true\n" })
		.mockResolvedValueOnce({ stdout: "false\n" });
	const extension = createExtension();
	const { ctx, setTheme } = createContext();

	await extension.start(ctx);
	expect(setTheme).toHaveBeenLastCalledWith("vitesse-dark");

	await vi.advanceTimersByTimeAsync(2000);
	expect(setTheme).toHaveBeenLastCalledWith("vitesse-light");

	await extension.shutdown(ctx);
	expect(vi.getTimerCount()).toBe(0);
});

test("does not change themes outside macOS", async () => {
	vi.spyOn(process, "platform", "get").mockReturnValue("linux");
	const extension = createExtension();
	const { ctx, setTheme } = createContext();

	await extension.start(ctx);

	expect(execFileAsync).not.toHaveBeenCalled();
	expect(setTheme).not.toHaveBeenCalled();
});

test("reports an initial theme error", async () => {
	vi.spyOn(process, "platform", "get").mockReturnValue("darwin");
	execFileAsync.mockResolvedValue({ stdout: "true\n" });
	const extension = createExtension();
	const { ctx, notify, setTheme } = createContext();
	setTheme.mockReturnValue({ success: false, error: "theme not found" });

	await extension.start(ctx);

	expect(notify).toHaveBeenCalledWith(
		"Vitesse system theme failed: theme not found",
		"error",
	);
	await extension.shutdown(ctx);
});
