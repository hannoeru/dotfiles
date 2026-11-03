import { readFileSync } from "node:fs";
import { join } from "node:path";
import { getAgentDir, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

export default function preloadedSkills(pi: ExtensionAPI): void {
	const instructions = readFileSync(join(getAgentDir(), "APPEND_SYSTEM.md"), "utf8").trim();

	pi.on("before_agent_start", ({ systemPromptOptions }) => {
		systemPromptOptions.appendSystemPrompt = systemPromptOptions.appendSystemPrompt.replace(instructions, "").trim();
		systemPromptOptions.sections.preloaded_skills = instructions;
	});
}
