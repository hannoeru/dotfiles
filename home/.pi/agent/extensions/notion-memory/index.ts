import { join } from "node:path";
import { type ExtensionAPI, type ExtensionContext, getAgentDir } from "@earendil-works/pi-coding-agent";
import { FileOAuthStore } from "./auth-store.ts";
import { isAuthRequired, NotionMemoryClient, type TransportFactory } from "./client.ts";
import { type BranchMemoryState, buildPromptSection, planRecall, type RecallDetails, runRecall } from "./recall.ts";

const SERVER_URL = "https://mcp.notion.com/mcp";
const MCP_SERVER_NAME = "notion";
const AUTH_FILE = "notion-memory-auth.json";
const CUSTOM_TYPE = "notion-memory";
const SECTION_KEY = "notion_memory";
const RECALL_TIMEOUT_MS = 5000;
const SIGN_IN_TIMEOUT_MS = 5 * 60 * 1000;
const SIGN_IN_HINT = "Notion memory is not signed in. Run /notion-memory login to enable recall.";

export interface NotionMemoryOptions {
	agentDir?: string;
	createTransport?: TransportFactory;
}

function branchState(ctx: ExtensionContext): BranchMemoryState {
	const state: BranchMemoryState = { recalled: false, seenIds: new Set() };
	for (const entry of ctx.sessionManager.buildContextEntries()) {
		if (entry.type !== "custom_message" || entry.customType !== CUSTOM_TYPE) continue;
		state.recalled = true;
		for (const id of (entry.details as RecallDetails).ids) state.seenIds.add(id);
	}
	return state;
}

function isTimeout(error: unknown): boolean {
	return error instanceof Error && (error.name === "TimeoutError" || error.name === "AbortError");
}

function openBrowser(pi: ExtensionAPI, url: string): void {
	const [command, args]: [string, string[]] =
		process.platform === "darwin" ? ["open", [url]] : ["xdg-open", [url]];
	void pi.exec(command, args, { timeout: 10_000 }).catch(() => undefined);
}

export function createNotionMemory(options: NotionMemoryOptions = {}) {
	return (pi: ExtensionAPI): void => {
		const agentDir = options.agentDir ?? getAgentDir();
		const auth = new FileOAuthStore(join(agentDir, AUTH_FILE));
		const client = new NotionMemoryClient({ serverUrl: SERVER_URL, auth, createTransport: options.createTransport });
		let recalledCount = 0;
		let warnedSignIn = false;
		let warnedFailure = false;

		const setStatus = (ctx: ExtensionContext) => {
			if (!ctx.hasUI) return;
			const text =
				client.state === "needs-auth" || !auth.hasTokens(SERVER_URL)
					? "notion memory: not signed in"
					: recalledCount > 0
						? `notion memory: ${recalledCount}`
						: undefined;
			ctx.ui.setStatus(CUSTOM_TYPE, text);
		};

		const reportFailure = (ctx: ExtensionContext, error: unknown) => {
			if (!ctx.hasUI) return;
			if (isAuthRequired(error)) {
				if (!warnedSignIn) ctx.ui.notify(SIGN_IN_HINT, "warning");
				warnedSignIn = true;
			} else if (!isTimeout(error) && !warnedFailure) {
				ctx.ui.notify(`Notion memory recall failed: ${error instanceof Error ? error.message : String(error)}`, "warning");
				warnedFailure = true;
			}
		};

		pi.on("session_start", async (_event, ctx) => {
			if (auth.hasTokens(SERVER_URL)) {
				void client.getClient().then(
					() => client.memoryGuide(),
					() => undefined,
				);
			} else if (ctx.hasUI && !warnedSignIn) {
				ctx.ui.notify(SIGN_IN_HINT, "info");
				warnedSignIn = true;
			}
			setStatus(ctx);
		});

		pi.on("session_shutdown", async () => {
			await client.close();
		});

		pi.on("before_agent_start", async (event, ctx) => {
			if (event.messageType !== "user") return;
			const signedIn = auth.hasTokens(SERVER_URL);
			// AbortSignal.timeout uses an unreferenced timer, which lets the process exit while Notion hangs.
			const deadline = new AbortController();
			const timer = setTimeout(
				() => deadline.abort(new DOMException("Notion memory recall timed out", "TimeoutError")),
				RECALL_TIMEOUT_MS,
			);
			const signal = ctx.signal ? AbortSignal.any([deadline.signal, ctx.signal]) : deadline.signal;
			const state = branchState(ctx);
			const plan = signedIn ? planRecall(state, event.prompt ?? "") : undefined;

			const [guide, recall] = await Promise.all([
				signedIn ? client.memoryGuide(signal).catch(() => undefined) : undefined,
				plan
					? runRecall(client, plan, state, signal).then(
							(result) => ({ ok: true as const, result }),
							(error: unknown) => ({ ok: false as const, error }),
						)
					: undefined,
			]).finally(() => clearTimeout(timer));

			event.systemPromptOptions.sections[SECTION_KEY] = buildPromptSection(MCP_SERVER_NAME, guide);

			if (recall && !recall.ok) reportFailure(ctx, recall.error);
			const result = recall?.ok ? recall.result : undefined;
			if (result) recalledCount += result.details.ids.length + (result.details.about ? 1 : 0);
			setStatus(ctx);
			if (!result) return;
			return { message: { customType: CUSTOM_TYPE, content: result.content, display: false, details: result.details } };
		});

		pi.registerCommand("notion-memory", {
			description: "Notion memory: status, login, logout",
			getArgumentCompletions: (prefix) =>
				["status", "login", "logout"]
					.filter((name) => name.startsWith(prefix.trim()))
					.map((name) => ({ value: name, label: name })),
			handler: async (args, ctx) => {
				const subcommand = args.trim() || "status";
				if (subcommand === "status") {
					ctx.ui.notify(
						[
							`signed in: ${auth.hasTokens(SERVER_URL) ? "yes" : "no"}`,
							`connection: ${client.state}${client.lastError ? ` (${client.lastError})` : ""}`,
							`memories recalled in this session: ${recalledCount}`,
						].join("\n"),
						"info",
					);
				} else if (subcommand === "login") {
					if (!ctx.hasUI) {
						ctx.ui.notify("Notion sign-in requires interactive mode.", "error");
						return;
					}
					try {
						await client.signIn(
							{
								showAuthorizationUrl: (url) => {
									ctx.ui.notify(`Sign in to Notion in your browser:\n${url.href}`, "info");
									openBrowser(pi, url.href);
								},
								promptForRedirectUrl: (signal) =>
									ctx.ui.input(
										"If the browser cannot reach this machine, paste the URL that it opened:",
										"http://127.0.0.1:…/callback?code=…",
										{ signal },
									),
							},
							AbortSignal.timeout(SIGN_IN_TIMEOUT_MS),
						);
						warnedSignIn = false;
						warnedFailure = false;
						ctx.ui.notify("Signed in to Notion. Recall starts with the next prompt.", "info");
					} catch (error) {
						ctx.ui.notify(`Notion sign-in failed: ${error instanceof Error ? error.message : String(error)}`, "error");
					}
				} else if (subcommand === "logout") {
					const removed = await client.signOut();
					ctx.ui.notify(removed ? "Signed out of Notion memory." : "Notion memory was not signed in.", "info");
				} else {
					ctx.ui.notify("Usage: /notion-memory [status|login|logout]", "error");
				}
				setStatus(ctx);
			},
		});
	};
}

export default createNotionMemory();
