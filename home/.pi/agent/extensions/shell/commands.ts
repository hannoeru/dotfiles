const RESERVED_WORDS = new Set(["!", "{", "}", "if", "then", "elif", "else", "fi", "while", "until", "do", "done", "esac"]);
const ASSIGNMENT = /^[A-Za-z_]\w*=/;
const WRAPPERS: Record<string, { valueOptions: string[]; operands?: number }> = {
	time: { valueOptions: [] },
	command: { valueOptions: [] },
	exec: { valueOptions: ["-a"] },
	nohup: { valueOptions: [] },
	env: { valueOptions: ["-u", "--unset", "-C", "--chdir", "-S", "--split-string"] },
	sudo: { valueOptions: ["-u", "--user", "-g", "--group", "-h", "--host", "-p", "--prompt", "-C", "-D", "-r", "-t", "-U"] },
	nice: { valueOptions: ["-n", "--adjustment"] },
	timeout: { valueOptions: ["-s", "--signal", "-k", "--kill-after"], operands: 1 },
	watch: { valueOptions: ["-n", "--interval", "-q", "--equexit"] },
	xargs: {
		valueOptions: ["-n", "--max-args", "-I", "--replace", "-L", "--max-lines", "-P", "--max-procs", "-d", "--delimiter", "-s", "-E", "-a", "--arg-file"],
	},
};
const SHELLS = new Set(["sh", "bash", "zsh", "dash"]);
const FIND_ACTIONS = new Set(["-exec", "-execdir", "-ok", "-okdir"]);

function parseSimpleCommands(script: string): string[][] {
	const commands: string[][] = [];
	const heredocs: { delimiter: string; stripTabs: boolean }[] = [];
	let words: string[] = [];
	let word: string | undefined;
	let pendingHeredoc: { stripTabs: boolean } | undefined;

	const endWord = () => {
		if (word === undefined) return;
		if (pendingHeredoc) heredocs.push({ delimiter: word, ...pendingHeredoc });
		else words.push(word);
		pendingHeredoc = undefined;
		word = undefined;
	};
	const endCommand = () => {
		endWord();
		if (words.length > 0) commands.push(words);
		words = [];
	};

	for (let i = 0; i < script.length; i++) {
		const char = script[i];
		if (char === "'") {
			const end = script.indexOf("'", i + 1);
			const close = end === -1 ? script.length : end;
			word = (word ?? "") + script.slice(i + 1, close);
			i = close;
		} else if (char === '"') {
			word ??= "";
			for (i++; i < script.length && script[i] !== '"'; i++) {
				if (script[i] === "\\") i++;
				word += script[i] ?? "";
			}
		} else if (char === "\\") {
			i++;
			if (i < script.length && script[i] !== "\n") word = (word ?? "") + script[i];
		} else if (char === "#" && word === undefined) {
			const newline = script.indexOf("\n", i);
			i = (newline === -1 ? script.length : newline) - 1;
		} else if (char === "\n") {
			endCommand();
			for (const heredoc of heredocs.splice(0)) i = skipHeredoc(script, i + 1, heredoc);
		} else if (";&|()`".includes(char)) {
			if (char === "(" && word === "$") word = undefined;
			endCommand();
		} else if (script.startsWith("<<<", i)) {
			endWord();
			i += 2;
		} else if (script.startsWith("<<", i)) {
			endWord();
			const stripTabs = script[i + 2] === "-";
			pendingHeredoc = { stripTabs };
			i += stripTabs ? 2 : 1;
		} else if (char === "<" || char === ">") {
			endWord();
			if (script[i + 1] === "&" || script[i + 1] === "|") i++;
		} else if (char === " " || char === "\t") {
			endWord();
		} else {
			word = (word ?? "") + char;
		}
	}
	endCommand();
	return commands;
}

function skipHeredoc(
	script: string,
	bodyStart: number,
	{ delimiter, stripTabs }: { delimiter: string; stripTabs: boolean },
) {
	let lineStart = bodyStart;
	while (lineStart < script.length) {
		const newline = script.indexOf("\n", lineStart);
		const lineEnd = newline === -1 ? script.length : newline;
		const line = script.slice(lineStart, lineEnd);
		if ((stripTabs ? line.replace(/^\t+/, "") : line) === delimiter) return lineEnd;
		lineStart = lineEnd + 1;
	}
	return script.length;
}

export type ProgramCall = { program: string; args: string[] };

function callsIn(words: string[]): ProgramCall[] {
	let i = 0;
	while (i < words.length && (RESERVED_WORDS.has(words[i]) || ASSIGNMENT.test(words[i]))) i++;
	if (i === words.length) return [];

	const program = words[i].split("/").at(-1) ?? "";
	const args = words.slice(i + 1);
	const wrapper = WRAPPERS[program];
	if (wrapper) {
		let operands = wrapper.operands ?? 0;
		let j = 0;
		for (; j < args.length; j++) {
			if (wrapper.valueOptions.includes(args[j])) j++;
			else if (args[j].startsWith("-") || ASSIGNMENT.test(args[j])) continue;
			else if (operands > 0) operands--;
			else break;
		}
		return callsIn(args.slice(j));
	}
	if (program === "eval") return programCalls(args.join(" "));
	if (program === "find") {
		return [
			{ program, args },
			...args.flatMap((arg, k) => {
				if (!FIND_ACTIONS.has(arg)) return [];
				const action = args.slice(k + 1);
				const end = action.findIndex((word) => word === ";" || word === "+");
				return callsIn(end === -1 ? action : action.slice(0, end));
			}),
		];
	}
	const flag = SHELLS.has(program) ? args.findIndex((arg) => /^-[a-z]*c$/.test(arg)) : -1;
	const script = flag === -1 ? undefined : args[flag + 1];
	return [{ program, args }, ...(script === undefined ? [] : programCalls(script))];
}

export function programCalls(script: string): ProgramCall[] {
	return parseSimpleCommands(script).flatMap(callsIn);
}

export function positionals(args: string[], valueOptions: Set<string>) {
	const words: string[] = [];
	for (let i = 0; i < args.length && args[i] !== "--"; i++) {
		if (valueOptions.has(args[i])) i++;
		else if (!args[i].startsWith("-")) words.push(args[i]);
	}
	return words;
}
