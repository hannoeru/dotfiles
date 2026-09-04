/**
 * Git Checkpoint Extension
 *
 * Before each turn, this extension saves the full work tree (tracked changes
 * and new untracked files) as a durable git commit object under a private ref.
 * The ref name is derived from the session entry id, so the checkpoint survives
 * process restarts and git garbage collection.
 *
 * When you fork or clone with `/fork` or `/clone`, the extension offers to reset
 * the code to the state it had at that point. Before it resets, it saves the
 * current work tree as a backup ref, so no work is lost.
 */

import { randomBytes } from "node:crypto";
import { tmpdir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const REF_PREFIX = "refs/pi-checkpoint";

function checkpointRef(entryId: string): string {
	return `${REF_PREFIX}/${entryId}`;
}

export default function (pi: ExtensionAPI) {
	// Run a git command. Returns the result without throwing on a non-zero code.
	async function git(args: string[], cwd: string) {
		return pi.exec("git", args, { cwd });
	}

	// True when cwd is inside a git work tree.
	async function insideWorkTree(cwd: string): Promise<boolean> {
		const res = await git(["rev-parse", "--is-inside-work-tree"], cwd);
		return res.code === 0 && res.stdout.trim() === "true";
	}

	// Save the full work tree (tracked changes and untracked files) as a commit
	// object and point `ref` at it. Uses a throwaway index file, so the real
	// index and work tree stay untouched. Returns the commit id, or undefined on
	// failure or when there is nothing to record.
	async function saveSnapshot(cwd: string, ref: string, message: string): Promise<string | undefined> {
		const tmpIndex = join(tmpdir(), `pi-checkpoint-index-${randomBytes(8).toString("hex")}`);
		// A single shell keeps the throwaway index scoped to this snapshot.
		// Positional args ($1..$4) avoid any interpolation of caller values.
		const script = [
			"set -e",
			'cd "$1"',
			'export GIT_INDEX_FILE="$3"',
			// Checkpoints are durable Git objects, so common secret files must not
			// enter refs that can later move through clones or mirrors.
			"git add -A -- ':!*.pem' ':!*.key' ':!id_rsa*' ':!id_ed25519*' ':!id_ecdsa*' ':!*.p12' ':!*.pfx' ':!.env' ':!.env.*' ':!*credentials*' ':!.aws' ':!.azure' ':!.kube' ':!.config/gcloud' ':!*.tfstate' ':!*.tfvars'",
			"tree=$(git write-tree)",
			'if git rev-parse -q --verify HEAD >/dev/null 2>&1; then',
			'  commit=$(git commit-tree "$tree" -p HEAD -m "$4")',
			"else",
			'  commit=$(git commit-tree "$tree" -m "$4")',
			"fi",
			'git update-ref "$2" "$commit"',
			'printf "%s" "$commit"',
		].join("\n");

		const res = await pi.exec(
			"bash",
			["-c", script, "pi-checkpoint", cwd, ref, tmpIndex, message],
			{ cwd },
		);
		// Best-effort cleanup of the throwaway index file.
		await pi.exec("rm", ["-f", tmpIndex], { cwd });

		if (res.code !== 0) return undefined;
		const commit = res.stdout.trim();
		return commit || undefined;
	}

	// Reset the work tree to the snapshot at `ref`. This overwrites tracked
	// changes, removes files added after the snapshot, and leaves the index in
	// sync with HEAD so the restored changes show up as normal modifications.
	async function restoreSnapshot(cwd: string, ref: string): Promise<boolean> {
		const script = [
			"set -e",
			'cd "$1"',
			'git read-tree -u --reset "$2^{tree}"',
			"git clean -fd",
			"git reset -q --mixed HEAD",
		].join("\n");
		const res = await pi.exec("bash", ["-c", script, "pi-checkpoint", cwd, ref], { cwd });
		return res.code === 0;
	}

	pi.on("turn_start", async (_event, ctx) => {
		const cwd = ctx.sessionManager.getCwd();
		if (!(await insideWorkTree(cwd))) return;

		const leaf = ctx.sessionManager.getLeafEntry();
		if (!leaf) return;

		await saveSnapshot(cwd, checkpointRef(leaf.id), `pi checkpoint for entry ${leaf.id}`);
	});

	pi.on("session_before_fork", async (event, ctx: ExtensionContext) => {
		if (!ctx.hasUI) return;

		const cwd = ctx.sessionManager.getCwd();
		if (!(await insideWorkTree(cwd))) return;

		const ref = checkpointRef(event.entryId);
		const verify = await git(["rev-parse", "-q", "--verify", `${ref}^{commit}`], cwd);
		if (verify.code !== 0) return; // No checkpoint for this entry.

		const choice = await ctx.ui.select("Restore code to this checkpoint?", [
			"Yes, reset code to that point",
			"No, keep current code",
		]);
		if (!choice?.startsWith("Yes")) return;

		// Back up the current work tree first so nothing is lost.
		const backupRef = `${REF_PREFIX}/backup-${Date.now()}`;
		await saveSnapshot(cwd, backupRef, "pi checkpoint backup before restore");

		const ok = await restoreSnapshot(cwd, ref);
		if (ok) {
			ctx.ui.notify(`Code reset to checkpoint. Backup saved at ${backupRef}`, "info");
		} else {
			ctx.ui.notify("Could not restore code to the checkpoint", "error");
		}
	});

	pi.registerCommand("checkpoints", {
		description: "List saved git checkpoints for this session",
		handler: async (_args, ctx) => {
			const cwd = ctx.sessionManager.getCwd();
			if (!(await insideWorkTree(cwd))) {
				ctx.ui.notify("Not inside a git work tree", "info");
				return;
			}
			const res = await git(
				["for-each-ref", "--sort=-creatordate", "--format=%(refname) %(creatordate:relative)", REF_PREFIX],
				cwd,
			);
			const lines = res.stdout.trim();
			ctx.ui.notify(lines ? `Checkpoints:\n${lines}` : "No checkpoints saved yet", "info");
		},
	});
}
