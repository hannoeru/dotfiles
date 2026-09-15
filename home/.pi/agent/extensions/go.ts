import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const RESUME_CUSTOM_TYPE = "go:resume";

function isResumeMarker(message: unknown): boolean {
	if (!message || typeof message !== "object") return false;
	const candidate = message as { role?: unknown; customType?: unknown };
	return candidate.role === "custom" && candidate.customType === RESUME_CUSTOM_TYPE;
}

/**
 * /go resumes the agent loop without the model seeing any new prompt text.
 *
 * The command sends a hidden custom marker that starts or queues a canonical
 * session turn. A context hook strips that marker before every provider call,
 * so the model continues from the existing transcript unchanged.
 */
export default function goExtension(pi: ExtensionAPI): void {
	pi.on("context", (event) => {
		const messages = event.messages.filter((message) => !isResumeMarker(message));
		if (messages.length !== event.messages.length) return { messages };
	});

	pi.registerCommand("go", {
		description: "Continue the agent loop without adding text to the context",
		handler: async () => {
			pi.sendMessage(
				{ customType: RESUME_CUSTOM_TYPE, content: [], display: false },
				{ triggerTurn: true, deliverAs: "followUp" },
			);
		},
	});
}