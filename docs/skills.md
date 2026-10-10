# Managed skills

The shared Home Manager configuration imports `modules/home/programs/skills.nix`.
The shared catalogue is in [`modules/home/skills.nix`](../modules/home/skills.nix).
Set `programs.skills.sources` in a machine's Home Manager configuration:

```nix
programs.skills.sources = [
  {
    source = "vercel-labs/agent-skills";
    category = "frontend";
    skills = [ "web-design-guidelines" ];
  }
  {
    source = "owner/repo/sub/path";
    category = "work";
  }
  {
    source = "/absolute/path/to/local-skills";
    category = "work";
    skills = null;
  }
  {
    source = "owner/unused-repo";
    category = "unused";
    skills = [ ];
  }
];
```

Each record has a nonempty `source` string, a `category` string, and an optional
`skills` list of nonempty strings. A category must match
`[A-Za-z0-9][A-Za-z0-9 &_-]*`. Omitted or null `skills` selects all skills.
An empty list selects none and makes no CLI call for that record. Null adds no
`--skill` flag, so native source syntax such as inline `@skill` filters stays
intact. Explicit lists publish only the requested original names. The runtime
requires every requested name, even if a provider installs extra staged skills.

The source parser belongs to Skills CLI. Source strings keep their native
meaning. Repository shorthand, repository subpaths, URLs, well-known sources,
and local paths use its native syntax.
Explicit relative local paths refer to the sync process's starting directory,
not the directory of the Nix file. Use absolute local paths in machine settings.
Explicit selected names must not start with `-`. After local path normalization,
a source must not start with `-` either. Skills CLI treats those arguments as
options. The runtime rejects them before any state write or CLI call.

## Categories and ownership

The runtime merges all records with the same category into one directory:

```text
~/.agents/skills/work/<installed-directory>/SKILL.md
```

A category is a directory, not a skill name namespace. The runtime preserves
frontmatter names. Duplicate original names across sources are errors, including
across different categories. Name matching is case-insensitive, as in Skills CLI.
Different names that produce the same installed directory within a category also
cause an error.

Each public category is a symlink to a copied generation under
`${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-skills/generations/`.
The runtime owns only category symlinks with valid marked-generation provenance.
It does not own the shared `~/.agents/skills` directory or manual siblings.

A manual category directory, file, or foreign symlink causes a visible error.
The runtime does not adopt it, overwrite it, or silently skip it. The public
`~/.agents` and `~/.agents/skills` parents must be real directories.
Choose a different category or move the conflicting entry yourself.

The runtime resolves and validates every source before it changes public links.
It installs into a separate project for each source with the pinned
`pkgs.skills`, using `add --agent universal --copy --yes`, never `--global`.
It then runs `list --agent universal --json` in that same project.
It checks the JSON paths and names against actual installed `SKILL.md` files
and the full installed directory set. Payload links must stay inside their
installed skill directory.

Publication replaces each category symlink atomically. It is not an atomic
whole-set transaction. An interrupted publication can expose categories from
different generations. Run the same sync command again to recover.

Garbage collection scans only the private generations root. It deletes only
marked generations that no public root symlink references. A manual alias to
a generation keeps it alive but does not become an owned link. Unknown private
directories and manual public files remain untouched. Do not edit generated
skill copies; change the source instead.

## Activation, retry, and cleanup

Home Manager runs the installed command after `linkGeneration`. Retry with:

```sh
dotfiles-skills-sync
```

The command and activation use the same Python engine and the same Nix-store
source specification. It serializes runs with a process lock.

To inspect known category changes without writes or CLI calls:

```sh
dotfiles-skills-sync --dry-run
```

Home Manager's `DRY_RUN` also selects this path. Dry-run reports existing manual
collisions but cannot inspect remote skill contents without fetching them.

To remove all owned category links, set:

```nix
programs.skills.sources = [ ];
```

Activate that configuration before removing the module import. An untouched
home with an empty list requires no directories or CLI calls. An empty
`skills` list also removes a category if no other record supplies it.

Activation fetches contents at the source's selected ref, or its current default
ref when none is specified. Nix pins the CLI, not the source contents. Network
errors fail activation visibly, and a Nix rollback does not restore an earlier
remote skill version.

The CLI inherits runtime `HOME`, XDG paths, and credential environment variables
so Git configuration, credential helpers, SSH agents, and GitHub authentication
remain available. It uses project scope; it does not update global Skills CLI
locks. Telemetry is disabled only for module calls. Private sources must work
non-interactively with those credentials. The module does not configure tokens
or interactive login.

## Verification

Run the same command as the native Linux and Darwin CI jobs:

```sh
scripts/test-skills.sh
```

The script builds native Skills CLI, Python, and the enabled module's generated
command through `tests/skills-module.nix`. Nix builds keep the real home for
store access. The behavior tests and generated command use temporary homes.
Fixtures include local source directories and a loopback HTTP server. The script
checks the published fixture `SKILL.md` and rejects an invalid category through
Nix evaluation. It does not activate Home Manager and needs no external source
repository for fixtures.

Run `nix fmt -- --ci` for formatting. The normal all-configuration evaluation
remains `scripts/check.sh`.
