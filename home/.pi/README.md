# Pi configuration

This directory is deployed to `~/.pi` by the Home Manager configuration.
The shared skills catalogue installs portable skills under `~/.agents/skills`.
`verify-dotfiles` is not one of them. It stays in this checkout at
`.agents/skills/verify-dotfiles`.
`analyze-issue`, `deslop`, `review-pr`, and `wrap-up` are Workflow skills in
the shared skills catalogue. This directory does not install `agent/prompts`.

## Default instructions

`agent/AGENTS.md` contains the shared policy and GitHub CLI rules.
Home Manager generates `~/.pi/agent/APPEND_SYSTEM.md` from the pinned Herdr
and poteto-mode skills in `modules/home/skills.nix`.
Pi receives both skill bodies before the first model request.
It loads their task-specific references only when needed.

Update the skill inputs in `flake.nix` and `flake.lock` to change the preloaded versions.
Relative references use the source paths in the generated prompt.
Poteto Mode applies by default, but explicit mode off takes precedence.
Herdr applies only when `HERDR_ENV=1`.
The generated instructions do not change pstack's stored mode state.

The preloaded-skills extension reads the generated file when the extension loads.
Before each run, it places those instructions in a dedicated system-prompt section.
It removes the same text from the append section to avoid duplication.
A trusted project's `.pi/APPEND_SYSTEM.md` keeps its normal precedence.
The dedicated section preserves both skill bodies alongside the project instructions.

## Validate changes

```sh
pnpm install --frozen-lockfile
pnpm test
pnpm typecheck
```

## Extensions

- `agent/extensions/git-interceptor.ts` prevents Git commands from opening an interactive editor and blocks Git hook bypass flags.
- `agent/extensions/handoff.ts` creates a focused prompt for a new Pi session.
- `agent/extensions/go.ts` adds `/go` to resume the agent loop without sending any new prompt text to the model.
- `agent/extensions/preloaded-skills.ts` preserves the generated skill instructions when a project supplies its own append file.
- `agent/extensions/notion-memory.ts` connects Pi to Notion Memory and tells the model when to use it.

## Notion memory

Notion Memory holds context, preferences, and decisions that the AI tools save in Notion.
The notion-memory extension registers Notion's MCP server as `notion`.
It declares the `notion-memory-search` and `notion-fetch` tools directly.
The other Notion tools are available through codemode.

The extension also adds a system-prompt section with these rules:

- At the start of each task, search Notion Memory with the key words of the task.
- In the first task of a session, read the About page.
- Before a memory is saved, updated, or forgotten, read Notion's memory guide.

The model does the recall, because a `before_agent_start` handler cannot call MCP tools.
Thus each task usually has one more tool call.

Sign in once in a Pi session.
`pi mcp login` does not load extensions, so use the slash command:

```text
/mcp login notion
```

A `notion` server in `~/.pi/agent/mcp.json` takes precedence over the registered server, and its tool exposure replaces the extension's.
Remove that entry with `pi mcp remove notion`.
Pi keeps sign-ins by server name and URL, so the registered server uses the same sign-in.

## Themes

- `agent/themes/vitesse-dark.json` provides the Vitesse dark palette.
- `agent/themes/vitesse-light.json` provides the Vitesse light palette.

Pi follows the terminal appearance through its built-in automatic theme selection.
It does not poll macOS System Events.
To use the Vitesse pair, set `theme` in `~/.pi/agent/settings.json`:

```json
{
  "theme": "vitesse-light/vitesse-dark"
}
```

Keep the other settings in that file. The light theme comes first.
Pi changes themes when the terminal reports an appearance change.
The terminal or terminal multiplexer must pass these notifications to Pi.
If the terminal reports no appearance or colors, Pi uses `COLORFGBG`, then dark.

To test the pair for one session without changing saved settings:

```sh
pi --use-theme vitesse-light/vitesse-dark
```

After deploying this checkout with Home Manager or nix-darwin, run `/reload`
in each existing Pi session when it is idle. New sessions use the deployed
configuration.
