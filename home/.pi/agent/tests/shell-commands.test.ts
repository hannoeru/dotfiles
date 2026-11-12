import { describe, expect, test } from "vitest";
import { positionals, programCalls } from "../extensions/shell/commands.ts";

const programs = (script: string) => programCalls(script).map(({ program, args }) => [program, ...args].join(" "));

describe("programCalls", () => {
	test.each([
		["git status", ["git status"]],
		["/usr/bin/git status", ["git status"]],
		["FOO=1 BAR=2 git status", ["git status"]],
		["a; b && c || d | e", ["a", "b", "c", "d", "e"]],
		["if git diff --quiet; then git push; fi", ["git diff --quiet", "git push"]],
		["echo $(git rev-parse HEAD)", ["echo", "git rev-parse HEAD"]],
		["git commit -m 'a; git push'", ["git commit -m a; git push"]],
		['git commit -m "a && git push"', ["git commit -m a && git push"]],
		["echo hi # git push", ["echo hi"]],
		["cat <<EOF\ngit push\nEOF\ngit status", ["cat", "git status"]],
		["cat <<-EOF\n\tgit push\n\tEOF\ngit status", ["cat", "git status"]],
	])("splits %j into simple commands", (script, expected) => {
		expect(programs(script)).toEqual(expected);
	});

	test.each([
		["time git push", ["git push"]],
		["command git push", ["git push"]],
		["exec -a name git push", ["git push"]],
		["nohup git push", ["git push"]],
		["env -u HOME FOO=1 git push", ["git push"]],
		["sudo -u root git push", ["git push"]],
		["nice -n 5 git push", ["git push"]],
		["timeout -s KILL 30 git push", ["git push"]],
		["watch -n 5 git push", ["git push"]],
		["xargs -n 1 -I {} git push", ["git push"]],
	])("unwraps %j", (script, expected) => {
		expect(programs(script)).toEqual(expected);
	});

	test.each([
		["bash -c 'git push'", ["bash -c git push", "git push"]],
		["sh -ec 'git push'", ["sh -ec git push", "git push"]],
		["bash script.sh", ["bash script.sh"]],
		["eval 'git push'", ["git push"]],
		["find . -exec git push \\;", ["find . -exec git push ;", "git push"]],
		["find . -execdir git add {} +", ["find . -execdir git add {} +", "git add {}"]],
		["find . -name x", ["find . -name x"]],
	])("reads the commands inside %j", (script, expected) => {
		expect(programs(script)).toEqual(expected);
	});
});

describe("positionals", () => {
	const valueOptions = new Set(["-C", "--repo"]);

	test.each([
		[["worktree", "add", "x"], ["worktree", "add", "x"]],
		[["-C", "dir", "worktree", "list"], ["worktree", "list"]],
		[["--repo", "o/r", "-q", "pr", "view"], ["pr", "view"]],
		[["push", "--", "-not-an-option"], ["push"]],
	])("%j → %j", (args, expected) => {
		expect(positionals(args, valueOptions)).toEqual(expected);
	});
});
