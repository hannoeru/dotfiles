import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { isToolCallEventType } from "@earendil-works/pi-coding-agent";
import { optionValues, positionals, programCalls } from "./shell/commands.ts";

type Verdict = { kind: "block" | "confirm"; reason: string };
type Rule = (args: string[], cwd: string) => Verdict | undefined;

const block = (reason: string): Verdict => ({ kind: "block", reason });
const confirm = (reason: string): Verdict => ({ kind: "confirm", reason });

const GITHUB_WRITE_REASON =
	"This writes to GitHub where other people see it. Draft the text for the human and post only when the human asks.";
const DIALOG_REASON = "Tell the human what the agent asks. The human answers its dialogs.";

const GH_VALUE_OPTIONS = new Set(["-R", "--repo", "-X", "--method", "-f", "-F", "--field", "--raw-field", "--input", "-H", "--header", "-b", "--body", "--body-file", "-t", "--title", "-q", "--jq", "-B", "--base"]);
const GH_WRITES: Record<string, Set<string>> = {
	issue: new Set(["create", "close", "reopen", "comment", "edit", "delete", "lock", "unlock", "pin", "unpin", "transfer", "develop"]),
	pr: new Set(["comment", "review", "close", "reopen", "merge", "lock", "unlock"]),
	label: new Set(["create", "edit", "delete", "clone"]),
	release: new Set(["create", "edit", "delete", "upload", "delete-asset"]),
	repo: new Set(["create", "delete", "edit", "archive", "unarchive", "rename"]),
	gist: new Set(["create", "edit", "delete", "rename"]),
	workflow: new Set(["run", "enable", "disable"]),
	run: new Set(["rerun", "cancel", "delete"]),
	secret: new Set(["set", "delete"]),
	variable: new Set(["set", "delete"]),
	cache: new Set(["delete"]),
};
const PR_EDIT_OWN_OPTIONS = new Set(["-t", "--title", "-b", "--body", "-F", "--body-file", "-B", "--base", "-R", "--repo"]);

function ghApiWrites(args: string[]) {
	const [method] = optionValues(args, ["-X", "--method"]);
	if (method) return method.toUpperCase() !== "GET";
	const fields = optionValues(args, ["-f", "-F", "--field", "--raw-field"]);
	const input = optionValues(args, ["--input"]).length > 0;
	if (positionals(args, GH_VALUE_OPTIONS)[1] !== "graphql") return input || fields.length > 0;
	return input || fields.some((field) => /^query=(?:@|\s*mutation\b)/.test(field));
}

const gh: Rule = (args) => {
	const [group, sub] = positionals(args, GH_VALUE_OPTIONS);
	const editsMetadata =
		group === "pr" && sub === "edit" && args.some((arg) => arg.startsWith("-") && !PR_EDIT_OWN_OPTIONS.has(arg.split("=")[0]));
	if (GH_WRITES[group]?.has(sub) || editsMetadata || (group === "api" && ghApiWrites(args))) return confirm(GITHUB_WRITE_REASON);
	return undefined;
};

const HERDR_VALUE_OPTIONS = new Set(["--machine", "--session", "--remote", "--kind", "--pane", "--timeout", "--workspace", "--cwd", "--branch", "--base", "--path", "--label", "--source", "--lines", "--format", "--until", "--direction", "--ratio", "--env"]);

const herdr: Rule = (args) => {
	const [group, sub] = positionals(args, HERDR_VALUE_OPTIONS);
	if (group === "server" && sub === "stop") return block("`herdr server stop` ends every pane, including the human's. Leave the server running.");
	if (group === "agent" && sub === "start") {
		const [kind] = optionValues(args, ["--kind"]);
		if (kind === undefined) return confirm("Start Pi agents with `--kind pi`.");
		if (kind !== "pi") return confirm(`Start Pi agents with \`--kind pi\`. Use \`--kind ${kind}\` only when the human asked for it.`);
	}
	if ((group === "agent" && sub === "send-keys") || (group === "pane" && (sub === "send-keys" || sub === "send-text"))) {
		return confirm(DIALOG_REASON);
	}
	return undefined;
};



const RULES: Record<string, Rule> = {
	gh,
	herdr,
};


function checkCommand(command: string, cwd: string): Verdict[] {
	const verdicts: Verdict[] = [];
	const calls = programCalls(command);
	for (const { program, args } of calls) {
		const verdict = RULES[program]?.(args, cwd);
		if (verdict) verdicts.push(verdict);
	}
	return verdicts;
}

export default function agentGuard(pi: ExtensionAPI): void {
	pi.on("tool_call", async (event, ctx) => {
		if (!isToolCallEventType("bash", event)) return;
		const verdicts = checkCommand(event.input.command, ctx.cwd);
		const blocked = verdicts.find((verdict) => verdict.kind === "block");
		if (blocked) return { block: true, reason: `BLOCKED: ${blocked.reason}` };
		if (verdicts.length === 0) return;

		const reasons = [...new Set(verdicts.map((verdict) => verdict.reason))].join("\n");
		const approved = ctx.hasUI && (await ctx.ui.confirm("Allow this command?", `${reasons}\n\n${event.input.command}`));
		if (!approved) return { block: true, reason: `BLOCKED: the human did not approve this command. ${reasons}` };
	});
}
