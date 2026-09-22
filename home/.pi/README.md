# Pi configuration

This directory is deployed to `~/.pi` by the Home Manager configuration.

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
