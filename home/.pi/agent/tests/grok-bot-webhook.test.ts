import type { ExtensionAPI, ExtensionContext, ExtensionEvent } from "@earendil-works/pi-coding-agent";
import { afterEach, expect, test, vi } from "vitest";
import webhook, { buildNotification } from "../extensions/grok-bot-webhook.ts";

const env = { GROK_BOT_WEBHOOK_URL: "http://localhost/hook", GROK_BOT_WEBHOOK_KEY: "test-key" };
const job = {
	startedAt: 1000,
	outcome: "completed" as const,
	summary: "Task complete.",
	cwd: "/workspace/project",
	repo: "project",
	session: "Task",
	host: "workstation",
	child: false,
};

const body = {
	event: "pi_job_done",
	status: "done",
	cwd: "/workspace/project",
	repo: "project",
	session: "Task",
	summary: "Task complete.",
	durationSeconds: 20,
	host: "workstation",
};

afterEach(() => {
	vi.unstubAllEnvs();
	vi.unstubAllGlobals();
	vi.restoreAllMocks();
});

test("builds the completion payload at the default threshold", () => {
	expect(buildNotification(job, env, 21000)).toEqual({ url: "http://localhost/hook", key: "test-key", body });
	expect(buildNotification({ ...job, outcome: "error" }, env, 21000)?.body).toEqual({ ...body, status: "error" });
});

test("keeps only 600 characters and omits unavailable metadata in JSON", () => {
	const notification = buildNotification({ ...job, summary: "x".repeat(650), repo: undefined, session: undefined }, env, 21000)!;
	expect(JSON.parse(JSON.stringify(notification.body))).toEqual({
		event: "pi_job_done", status: "done", cwd: "/workspace/project", summary: "x".repeat(600), durationSeconds: 20, host: "workstation",
	});
});

test.each([
	{ name: "missing URL", environment: { ...env, GROK_BOT_WEBHOOK_URL: "" }, run: job, now: 21000 },
	{ name: "missing key", environment: { ...env, GROK_BOT_WEBHOOK_KEY: "" }, run: job, now: 21000 },
	{ name: "disabled", environment: { ...env, GROK_BOT_WEBHOOK_DISABLE: "1" }, run: job, now: 21000 },
	{ name: "child session", environment: env, run: { ...job, child: true }, now: 21000 },
	{ name: "user abort", environment: env, run: { ...job, outcome: "aborted" as const }, now: 21000 },
	{ name: "short run", environment: env, run: job, now: 20999 },
	{ name: "custom threshold", environment: { ...env, GROK_BOT_WEBHOOK_MIN_SECONDS: "30" }, run: job, now: 21000 },
])("skips $name", ({ environment, run, now }) => {
	expect(buildNotification(run, environment, now)).toBeUndefined();
	expect(buildNotification(job, env, 21000)?.body).toEqual(body);
});

test.each(["invalid", "-1", "Infinity"])("uses the default threshold for %s", (minimum) => {
	const environment = { ...env, GROK_BOT_WEBHOOK_MIN_SECONDS: minimum };
	expect(buildNotification(job, environment, 20999)).toBeUndefined();
	expect(buildNotification(job, environment, 21000)?.body).toEqual(body);
});

test("allows a zero threshold", () => {
	expect(buildNotification(job, { ...env, GROK_BOT_WEBHOOK_MIN_SECONDS: "0" }, 1000)?.body).toEqual({ ...body, durationSeconds: 0 });
});

function loadExtension() {
	const handlers = new Map<string, (event: ExtensionEvent, context: ExtensionContext) => unknown>();
	webhook({ on: (name: string, handler: (event: ExtensionEvent, context: ExtensionContext) => unknown) => handlers.set(name, handler) } as unknown as ExtensionAPI);
	const context = {
		sessionManager: { getSessionName: () => "Task", getHeader: () => ({}) },
	} as unknown as ExtensionContext;
	return (name: string, event = {}) => handlers.get(name)!({ ...event, type: name } as ExtensionEvent, context);
}

test("sends once at settlement, after recovery, without waiting for HTTP", async () => {
	for (const [key, value] of Object.entries({ ...env, GROK_BOT_WEBHOOK_MIN_SECONDS: "0", GROK_BOT_WEBHOOK_DISABLE: "0" })) vi.stubEnv(key, value);
	const request = vi.fn().mockResolvedValue({ body: { cancel: vi.fn() } });
	vi.stubGlobal("fetch", request);
	vi.spyOn(Date, "now").mockReturnValue(1000);
	const emit = loadExtension();
	emit("before_agent_start");
	emit("agent_end", { messages: [{ role: "assistant", content: [{ type: "text", text: "Initial failure" }] }] });
	emit("agent_before_settle", { outcome: "error" });
	expect(request).toHaveBeenCalledTimes(0);
	vi.mocked(Date.now).mockReturnValue(22000);
	emit("before_agent_start");
	emit("agent_end", { messages: [{ role: "assistant", content: [{ type: "thinking", thinking: "private" }, { type: "text", text: "Recovered" }] }] });
	emit("agent_before_settle", { outcome: "completed" });
	expect(emit("agent_settled", { aborted: false })).toBeUndefined();
	emit("agent_settled", { aborted: false });
	await vi.waitFor(() => expect(request).toHaveBeenCalledTimes(1));
	const [url, options] = request.mock.calls[0];
	expect(url).toBe("http://localhost/hook");
	expect(options).toMatchObject({
		method: "POST", redirect: "error",
		headers: { "Content-Type": "application/json", Authorization: "Bearer test-key", "X-Automation-Key": "test-key" },
	});
	expect(options.signal).toBeInstanceOf(AbortSignal);
	expect(JSON.parse(options.body)).toMatchObject({ event: "pi_job_done", status: "done", session: "Task", summary: "Recovered", durationSeconds: 21 });
});

test("silently handles transport failure without retry", async () => {
	for (const [key, value] of Object.entries({ ...env, GROK_BOT_WEBHOOK_MIN_SECONDS: "0", GROK_BOT_WEBHOOK_DISABLE: "0" })) vi.stubEnv(key, value);
	const request = vi.fn().mockRejectedValue(new Error("network failure"));
	vi.stubGlobal("fetch", request);
	const emit = loadExtension();
	emit("before_agent_start");
	emit("agent_before_settle", { outcome: "error" });
	expect(emit("agent_settled", { aborted: false })).toBeUndefined();
	await vi.waitFor(() => expect(request).toHaveBeenCalledTimes(1));
	expect(JSON.parse(request.mock.calls[0][1].body).status).toBe("error");
});
