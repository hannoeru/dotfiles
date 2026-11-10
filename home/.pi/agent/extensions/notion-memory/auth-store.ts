import { createHash, randomBytes } from "node:crypto";
import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { McpRefreshLockBusyError, type McpOAuthServerStore, type McpOAuthState } from "@earendil-works/pi-mcp/oauth";
import lockfile from "proper-lockfile";

const LOCK_STALE_MS = 20_000;
const LOCK_WAIT_MS = 25_000;
const LOCK_RETRY_MS = 100;

type StoredStates = Record<string, McpOAuthState>;

/**
 * OAuth state of the extension's own Notion grant. Pi does not export its MCP credential store, and
 * Notion rotates refresh tokens, so a grant shared with Pi's MCP connection would sign one client out.
 */
export class FileOAuthStore {
	private readonly path: string;

	constructor(path: string) {
		this.path = path;
	}

	private read(): StoredStates {
		let text: string;
		try {
			text = readFileSync(this.path, "utf8");
		} catch {
			return {};
		}
		try {
			const parsed: unknown = JSON.parse(text);
			return typeof parsed === "object" && parsed !== null && !Array.isArray(parsed) ? (parsed as StoredStates) : {};
		} catch {
			return {};
		}
	}

	private write(states: StoredStates): void {
		mkdirSync(dirname(this.path), { recursive: true, mode: 0o700 });
		const temp = `${this.path}.${process.pid}.${randomBytes(4).toString("hex")}.tmp`;
		writeFileSync(temp, `${JSON.stringify(states, null, 2)}\n`, { mode: 0o600 });
		renameSync(temp, this.path);
	}

	forServer(serverUrl: string): McpOAuthServerStore {
		const key = String(new URL(serverUrl));
		const hash = createHash("sha256").update(key).digest("hex").slice(0, 16);
		const lockPath = join(dirname(this.path), `notion-memory-refresh-${hash}`);
		return {
			load: () => this.read()[key],
			save: (state) => {
				const states = this.read();
				states[key] = state;
				this.write(states);
			},
			withRefreshLock: async <T>(fn: () => Promise<T>): Promise<T> => {
				mkdirSync(dirname(lockPath), { recursive: true, mode: 0o700 });
				const release = await lockfile
					.lock(lockPath, {
						realpath: false,
						stale: LOCK_STALE_MS,
						retries: {
							retries: LOCK_WAIT_MS / LOCK_RETRY_MS,
							factor: 1,
							minTimeout: LOCK_RETRY_MS,
							maxTimeout: LOCK_RETRY_MS,
						},
						onCompromised: () => {},
					})
					.catch((error: unknown) => {
						if (error instanceof Error && "code" in error && error.code === "ELOCKED") throw new McpRefreshLockBusyError();
						throw error;
					});
				try {
					return await fn();
				} finally {
					await release().catch(() => undefined);
				}
			},
		};
	}

	hasTokens(serverUrl: string): boolean {
		return this.read()[String(new URL(serverUrl))]?.tokens !== undefined;
	}

	tokenFingerprint(serverUrl: string): string {
		const tokens = this.read()[String(new URL(serverUrl))]?.tokens;
		return tokens ? createHash("sha256").update(JSON.stringify(tokens)).digest("hex") : "";
	}

	remove(serverUrl: string): boolean {
		const states = this.read();
		const key = String(new URL(serverUrl));
		if (!(key in states)) return false;
		delete states[key];
		if (Object.keys(states).length === 0) rmSync(this.path, { force: true });
		else this.write(states);
		return true;
	}
}
