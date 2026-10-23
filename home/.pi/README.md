# Pi configuration

This directory is deployed to `~/.pi` by the Home Manager configuration.
The shared skills catalogue installs portable skills under `~/.agents/skills`.
`verify-dotfiles` is not one of them. It stays in this checkout at
`.agents/skills/verify-dotfiles`.
The prompt templates that lived in `agent/prompts` are the Workflow skills
`analyze-issue`, `deslop`, `review-pr`, and `wrap-up`. This directory does not
install `agent/prompts`.

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
in each existing Pi session when it is idle. This stops the old extension's
polling timer. New sessions use the deployed configuration.
Removing the extension from this checkout does not change an installed Nix
store copy or stop an extension that a running session has already loaded.
