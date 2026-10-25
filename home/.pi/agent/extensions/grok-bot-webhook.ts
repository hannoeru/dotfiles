import { execFile } from "node:child_process";
import { hostname } from "node:os";
import { basename } from "node:path";
import { promisify } from "node:util";
import type { AgentActivityOutcome, ExtensionAPI } from "@earendil-works/pi-coding-agent";

interface Run {
	startedAt: number;
	outcome: AgentActivityOutcome;
	summary: string;
}

interface Job extends Run {
	cwd: string;
	repo?: string;
	session?: string;
	host: string;
	child: boolean;
}

export function buildNotification(job: Job, env: NodeJS.ProcessEnv, now: number) {
	const url = env.GROK_BOT_WEBHOOK_URL;
	const key = env.GROK_BOT_WEBHOOK_KEY;
	const configuredMinimum = Number(env.GROK_BOT_WEBHOOK_MIN_SECONDS ?? 20);
	const minimum = Number.isFinite(configuredMinimum) && configuredMinimum >= 0 ? configuredMinimum : 20;
	const durationSeconds = (now - job.startedAt) / 1000;
	if (
		!url || !key || env.GROK_BOT_WEBHOOK_DISABLE === "1" || job.child ||
		job.outcome === "aborted" || durationSeconds < minimum
	) {
		return undefined;
	}
	return {
		url,
		key,
		body: {
			event: "pi_job_done",
			status: job.outcome === "error" ? "error" : "done",
			cwd: job.cwd,
			repo: job.repo,
			session: job.session,
			summary: job.summary.slice(0, 600),
			durationSeconds,
			host: job.host,
		},
	};
}

const exec = promisify(execFile);

async function sendNotification(job: Job, env: NodeJS.ProcessEnv, now: number) {
	try {
		const notification = buildNotification(job, env, now);
		if (!notification) return;
		const signal = AbortSignal.timeout(8000);
		try {
			const { stdout } = await exec("git", ["rev-parse", "--show-toplevel"], { cwd: job.cwd, signal });
			notification.body.repo = basename(stdout.trim());
		} catch {}
		const response = await fetch(notification.url, {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				Authorization: `Bearer ${notification.key}`,
				"X-Automation-Key": notification.key,
			},
			body: JSON.stringify(notification.body),
			signal,
			redirect: "error",
		});
		await response.body?.cancel();
	} catch {}
}

export default function (pi: ExtensionAPI) {
	let run: Run | undefined;

	pi.on("before_agent_start", () => {
		run ??= { startedAt: Date.now(), outcome: "completed", summary: "" };
	});
	pi.on("agent_end", (event) => {
		if (!run) return;
		const last = event.messages.findLast((message) => message.role === "assistant");
		if (last?.role === "assistant") {
			run.summary = last.content.filter((part) => part.type === "text").map((part) => part.text).join("\n");
		}
	});
	pi.on("agent_before_settle", (event) => {
		if (run) run.outcome = event.outcome;
	});
	pi.on("agent_settled", (event, ctx) => {
		const finished = run;
		run = undefined;
		if (!finished) return;
		void sendNotification({
			...finished,
			outcome: event.aborted ? "aborted" : finished.outcome,
			cwd: process.cwd(),
			session: ctx.sessionManager.getSessionName(),
			host: hostname(),
			child: Boolean(ctx.sessionManager.getHeader()?.parentSession),
		}, { ...process.env }, Date.now());
	});
}
