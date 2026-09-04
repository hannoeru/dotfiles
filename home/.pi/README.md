# Pi configuration

This directory is deployed to `~/.pi` by the Home Manager configuration.

## Validate changes

```sh
pnpm install --frozen-lockfile
pnpm test
pnpm typecheck
```

## Extensions

- `agent/extensions/git-checkpoint.ts` saves a work tree snapshot before each turn in a private `refs/pi-checkpoint/*` Git ref. Snapshots include tracked changes and non-ignored untracked files. They exclude common secret material, including private keys, certificates, `.env` files, credential files, cloud credential directories, and Terraform state or variable files.
- `agent/extensions/handoff.ts` creates a focused prompt for a new Pi session.

Checkpoint refs are durable Git objects. Do not put secrets in files that are not covered by the exclusion policy.
