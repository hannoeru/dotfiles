import { McpAuthRequiredError, McpClient, type McpTransport, StreamableHttpTransport } from "@earendil-works/pi-mcp";
import {
	completeMcpSignIn,
	createMcpAuthProvider,
	listenForLoopbackSignIn,
	type McpAuthProvider,
	McpOAuthAuthorizationRequiredError,
	type McpOAuthSettings,
	type OAuthChallenge,
	startMcpSignIn,
	waitForLoopbackSignIn,
} from "@earendil-works/pi-mcp/oauth";
import type { FileOAuthStore } from "./auth-store.ts";
import { type AboutPage, type MemoryHit, parseAboutPage, parseSearchResult, resultText } from "./recall.ts";

const CLIENT_NAME = "Pi Notion Memory";
const MEMORY_GUIDE_URI = "notion://docs/memory";
const OAUTH_SETTINGS: McpOAuthSettings = { clientRegistration: "dcr" };

export type ConnectionState = "idle" | "connecting" | "connected" | "needs-auth" | "failed";

export class NeedsSignInError extends Error {
	constructor() {
		super("Notion memory is not signed in. Run /notion-memory login.");
		this.name = "NeedsSignInError";
	}
}

export interface SignInPrompt {
	showAuthorizationUrl(url: URL): void;
	promptForRedirectUrl(signal: AbortSignal): Promise<string | undefined>;
}

export type TransportFactory = (url: string, authProvider: McpAuthProvider) => McpTransport;

export interface NotionMemoryClientOptions {
	serverUrl: string;
	auth: FileOAuthStore;
	createTransport?: TransportFactory;
}

export function isAuthRequired(error: unknown): boolean {
	for (let current = error, depth = 0; current && depth < 5; depth++) {
		if (
			current instanceof McpOAuthAuthorizationRequiredError ||
			current instanceof McpAuthRequiredError ||
			current instanceof NeedsSignInError
		) {
			return true;
		}
		current = current instanceof Error ? current.cause : undefined;
	}
	return false;
}

function raceSignal<T>(promise: Promise<T>, signal: AbortSignal | undefined): Promise<T> {
	if (!signal) return promise;
	if (signal.aborted) return Promise.reject(signal.reason);
	return new Promise<T>((resolve, reject) => {
		const onAbort = () => reject(signal.reason);
		signal.addEventListener("abort", onAbort, { once: true });
		promise.then(resolve, reject).finally(() => signal.removeEventListener("abort", onAbort));
	});
}

/**
 * Pi lets only tools call other tools, so the before_agent_start hook cannot use Pi's MCP connection.
 * This client talks to Notion's MCP server directly.
 */
export class NotionMemoryClient {
	state: ConnectionState = "idle";
	lastError: string | undefined;
	private readonly options: NotionMemoryClientOptions;
	private client: McpClient | undefined;
	private authProvider: McpAuthProvider | undefined;
	private connecting: Promise<McpClient> | undefined;
	private challenge: OAuthChallenge | undefined;
	private guide: string | undefined;
	private grantAtNeedsAuth = "";

	constructor(options: NotionMemoryClientOptions) {
		this.options = options;
	}

	private get store() {
		return this.options.auth.forServer(this.options.serverUrl);
	}

	private markNeedsAuth(): void {
		this.state = "needs-auth";
		this.lastError = undefined;
		this.grantAtNeedsAuth = this.options.auth.tokenFingerprint(this.options.serverUrl);
	}

	async getClient(signal?: AbortSignal): Promise<McpClient> {
		if (this.client?.connectionState === "connected") return this.client;
		if (this.state === "needs-auth") {
			if (this.options.auth.tokenFingerprint(this.options.serverUrl) === this.grantAtNeedsAuth) throw new NeedsSignInError();
			this.state = "idle";
		}
		this.connecting ??= this.connect().finally(() => {
			this.connecting = undefined;
		});
		return raceSignal(this.connecting, signal);
	}

	private async connect(): Promise<McpClient> {
		this.state = "connecting";
		const authProvider = createMcpAuthProvider({
			serverUrl: this.options.serverUrl,
			store: this.store,
			settings: () => OAUTH_SETTINGS,
			clientName: CLIENT_NAME,
			onChallenge: (challenge) => {
				this.challenge = challenge;
			},
		});
		const transport =
			this.options.createTransport?.(this.options.serverUrl, authProvider) ??
			new StreamableHttpTransport({ url: this.options.serverUrl, authProvider, openGetStream: false });
		const client = new McpClient({ name: "pi-notion-memory", version: "1.0.0", requestTimeoutMs: 30_000 });
		try {
			await client.connect(transport);
		} catch (error) {
			await client.close().catch(() => undefined);
			if (isAuthRequired(error)) {
				this.markNeedsAuth();
				throw new NeedsSignInError();
			}
			this.state = "failed";
			this.lastError = error instanceof Error ? error.message : String(error);
			throw error;
		}
		client.onClose(() => {
			if (this.client !== client) return;
			this.client = undefined;
			if (this.state === "connected") this.state = "idle";
		});
		this.client = client;
		this.authProvider = authProvider;
		this.state = "connected";
		this.lastError = undefined;
		return client;
	}

	private async run<T>(signal: AbortSignal | undefined, fn: (client: McpClient) => Promise<T>): Promise<T> {
		const client = await this.getClient(signal);
		try {
			return await fn(client);
		} catch (error) {
			if (!isAuthRequired(error)) throw error;
			await this.dropClient();
			this.markNeedsAuth();
			throw new NeedsSignInError();
		}
	}

	search(query: string, limit: number, signal?: AbortSignal): Promise<MemoryHit[]> {
		return this.run(signal, async (client) => {
			const result = await client.callTool("notion-memory-search", { query, limit }, { signal });
			if (result.isError) throw new Error(`notion-memory-search failed: ${resultText(result).slice(0, 300)}`);
			return parseSearchResult(result);
		});
	}

	about(signal?: AbortSignal): Promise<AboutPage | undefined> {
		return this.run(signal, async (client) => {
			const result = await client.callTool("notion-fetch", { id: "memory" }, { signal });
			return result.isError ? undefined : parseAboutPage(result);
		});
	}

	async memoryGuide(signal?: AbortSignal): Promise<string | undefined> {
		this.guide ??= await this.run(signal, async (client) => {
			const { contents } = await client.readResource(MEMORY_GUIDE_URI, { signal });
			const text = contents.map((item) => ("text" in item ? item.text : "")).join("\n").trim();
			return text || undefined;
		});
		return this.guide;
	}

	async signIn(prompt: SignInPrompt, signal: AbortSignal): Promise<void> {
		const { serverUrl } = this.options;
		const store = this.store;
		const { callback, redirectUrl } = await listenForLoopbackSignIn({ serverUrl, store, settings: OAUTH_SETTINGS });
		try {
			const signIn = {
				serverUrl,
				store,
				settings: OAUTH_SETTINGS,
				redirectUrl,
				challenge: this.challenge,
				signal,
				clientName: CLIENT_NAME,
			};
			const authorization = await startMcpSignIn(signIn);
			if (authorization.kind === "redirect") {
				prompt.showAuthorizationUrl(new URL(authorization.authorizationUrl));
				const response = await waitForLoopbackSignIn({
					callback,
					authorization,
					promptForRedirectUrl: prompt.promptForRedirectUrl,
					signal,
				});
				await completeMcpSignIn({ ...signIn, authorization, response });
			}
		} finally {
			await callback.close();
		}
		this.challenge = undefined;
		await this.dropClient();
		this.state = "idle";
		await this.getClient(signal);
	}

	async signOut(): Promise<boolean> {
		await this.dropClient();
		const removed = this.options.auth.remove(this.options.serverUrl);
		this.markNeedsAuth();
		return removed;
	}

	private async dropClient(): Promise<void> {
		const client = this.client;
		this.client = undefined;
		await this.authProvider?.settled().catch(() => undefined);
		this.authProvider = undefined;
		await client?.close().catch(() => undefined);
	}

	async close(): Promise<void> {
		await this.dropClient();
		if (this.state === "connected" || this.state === "connecting") this.state = "idle";
	}
}
