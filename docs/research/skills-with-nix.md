# Managing agent skills with Nix

## Overview

Use the existing Home Manager file mechanism first. Pin external skill repositories as `flake = false` inputs, select individual skill directories, and link portable skills under `~/.agents/skills`. Pi already discovers that location. Keep Pi-only local skills in `~/.pi/agent/skills` and workflow packages, including pi-pstack, under Pi package management. Do not extract their skills into a second installation. [L1, L2, L4]

`Kyure-A/agent-skills-nix` exists and has a Home Manager module with Pi targets. It adds useful discovery and selection, but also bundle construction and destination synchronization. These are not necessary for a short, explicit list of skills. This is a recommendation from source inspection, not a tested deployment. [P3, P4, P5, P6, P7]

## Key concepts

- A skill is a directory with `SKILL.md` and optional scripts, references, and assets. Install the complete directory, not only its Markdown file. [L4]
- A non-flake input supplies a source tree without evaluating the upstream repository's flake outputs. `flake.lock` records its revision and content hash. This pins files, not their runtime environment or safety. [P1]
- Home Manager `home.file` links source paths into the home directory. The default links a whole directory. `recursive = true` creates directories with file-level links, so unmanaged siblings can coexist. Neither layout makes store files writable. [P2]
- Pi packages are a separate resource mechanism. They can include extensions and runtime dependencies as well as skills. Pi loads local package paths without installing their dependencies. A Nix skill link does not replace package installation. [L4]

## How it works

The current `flake.nix` already provides the model through its non-flake `nanorc` input. It passes that input to standalone Home Manager through `extraSpecialArgs`. On Darwin, it passes the input to `modules/darwin.nix`, which forwards it through `home-manager.extraSpecialArgs`. A future skills input would need the same complete path. No configuration was changed for this research. [L1, L2]

Home Manager currently deploys `home/.pi` with `recursive = true`. That includes the local `bro` and `nuxt-cloudflare` skills. On this host, both `SKILL.md` files are links into `/nix/store/qq3q485qqyfswpbiybwsdmm0hda71sl1-home-manager-files/.pi/agent/skills/`. The directory itself is not one read-only link. [L1, L3; host inspection]

For portable external skills, declare one source input per repository and one `home.file` target per selected skill under `.agents/skills/<name>`. The source is the input's actual skill subdirectory. Keep the default `force = false`. A whole-directory link is simplest for an immutable skill; use recursive links only when writable siblings are required. Keep the containing skills directory available for other owners. Review the selected files when updating the lock. At startup or `/reload`, Pi discovers the installed skills and advertises their descriptions. It reads full instructions when needed. [P1, P2, L4]

With `agent-skills-nix`, the module instead discovers a catalog, selects IDs, builds a store bundle, and installs target-specific bundles. It accepts input-backed or path-backed sources. Its root flake declares only nixpkgs; Home Manager is a test-only dependency according to its README. The library can follow this repo's nixpkgs. Its optional npins source registry is not required for flake inputs. Tree synchronization adds Bash, coreutils, jq, and rsync. Bundle construction also uses rsync and findutils. [P3, P4, P5, P6, P7]

| Choice | Benefit | Cost and recommendation |
|---|---|---|
| Plain `home.file` plus non-flake inputs | Uses existing dependencies, explicit skill selection, one lock file | Paths and required tools need manual review. Recommended now. |
| `agent-skills-nix` | Recursive discovery, unknown-ID checks, target selection, transformations and tool links | Adds an API, build logic, and directory ownership rules. Use only if those capabilities remove substantial repeated work. |
| `papercomputeco/flake-skills` | Shared and composite skill flakes, project dev-shell installation | Its README describes shell-entry sync and stale-skill cleanup. This is a project distribution model, not needed for this home configuration. [P8] |
| `bitbloxhub/skills-flake` | Prepackaged skill catalog and Home Manager Pi destination | Adds catalog selection and a KDL/JSON source-update workflow. README-only review does not establish a reliability benefit here. [P9] |

## Where things live

- `flake.nix` and `flake.lock` own external source declarations and pins.
- `modules/home/default.nix` owns shared home files. `modules/darwin.nix` forwards Home Manager arguments on Macs.
- `home/.pi/agent/skills` owns repository-local Pi skills. `home/.pi/README.md` documents deployment and extension checks.
- `~/.agents/skills` is the recommended destination for selected portable skills, not a claim that every agent supports it.
- `~/.pi/agent/settings.json` owns personal Pi package declarations. Do not give Nix and Pi's package commands competing ownership of that file. [L1, L2, L3, L4]

## Gotchas

- **Library takeover risk.** The library's Home Manager `link` mode sets both `recursive = true` and `force = true`. Home Manager documents that force silently deletes an existing target. The default library targets use `symlink-tree`, not `link`. Its README specifies `rsync --delete`, an ownership marker, refusal of non-empty unmarked destinations, and a force override. Once a directory is library-owned, unrelated files are at risk during synchronization. Do not enable either mode over the existing mixed `~/.pi/agent/skills` or `~/.agents/skills` tree without a separate ownership plan. [P2, P3, P5, P6]
- **Catalog IDs are not Pi names.** `idPrefix` and output-directory renaming do not automatically change `SKILL.md` frontmatter. Pi keys collisions by the frontmatter name, with a directory-name fallback. The first discovered name wins. It separately skips identical files reached through multiple symlinks. Prefixing two `pdf` catalog entries therefore does not fix two declared `name: pdf` skills. [L4, L5, P3, P7]
- **Store paths affect scripts.** A script that writes beside itself can fail. A script that resolves its own real path can reach the read-only store even through recursive home links. Keep caches and output outside the installed skill. Check relative references and links to shared sibling files before selecting a directory. The library drops escaping or dangling source links; it does not make every upstream skill runnable. [P2, P3, P7]
- **Tool availability is separate.** Plain skill links do not install Python, Node dependencies, browsers, or credentials. Add only required tools through the existing environment. Library tool links and command rewriting do not prove that upstream scripts use those tools correctly. [L4, P7]

## Verified sources and limits

The research used local configuration, installed Pi documentation, upstream source through `gh`, and the two existing host links. The main agent reviewed the research note and checked the Home Manager and library file ownership rules. No `CONTEXT.md` files were found in the repository or checked parent directories.

An offline Nix evaluation confirmed that `homeConfigurations.ephemeral.config.home.file.".pi"` has `recursive = true`, a store-backed source, and target `.pi`. The evaluation used `--no-write-lock-file`. This confirms the existing configuration, not a proposed deployment.

Local source paths are relative to `/Users/hanlee/dotfiles`, except Pi sources:

- L1: `modules/home/default.nix`.
- L2: `flake.nix`, `flake.lock`, and `modules/darwin.nix`.
- L3: `home/.pi/README.md` and the host links described above.
- L4: Installed Pi 0.99.2 `docs/skills.md`, `docs/packages.md`, `docs/settings.md`, `docs/configuration.md`, `docs/cli.md`, and `docs/security.md`. Also read the linked `docs/extensions.md`, `docs/prompt-templates.md`, and `docs/themes.md`. Installation root: `/Users/hanlee/.local/share/mise/installs/npm-earendil-works-pi-coding-agent/0.99.2/node_modules/.mise/@earendil-works+pi-coding-agent@0.99.2/node_modules/@earendil-works/pi-coding-agent`.
- L5: `dist/core/skills.js` under that installation root, specifically `loadSkillFromFile` and `loadSkills`.

Exact primary-source API URLs read through `gh api`:

- [P1: Nix flake manual source](https://api.github.com/repos/NixOS/nix/contents/src/nix/flake.md?ref=master). Master HEAD observed as `9bf3582eafaa03e484bd086f6cccc8ea08621460`; the content request used the branch, not the commit.
- [P2: Home Manager file options at this repo's pinned revision](https://api.github.com/repos/nix-community/home-manager/contents/modules/lib/file-type.nix?ref=c8ecc29e5175452bee4a2aa1ba2383856d795338).
- [P3: agent-skills-nix README](https://api.github.com/repos/Kyure-A/agent-skills-nix/contents/README.md?ref=dc122af897ab9a685c20ae54c639021619dbbb52).
- [P4: agent-skills-nix flake](https://api.github.com/repos/Kyure-A/agent-skills-nix/contents/flake.nix?ref=dc122af897ab9a685c20ae54c639021619dbbb52).
- [P5: Home Manager module](https://api.github.com/repos/Kyure-A/agent-skills-nix/contents/modules/home-manager/agent-skills.nix?ref=dc122af897ab9a685c20ae54c639021619dbbb52).
- [P6: Target defaults and sync dependencies](https://api.github.com/repos/Kyure-A/agent-skills-nix/contents/lib/targets.nix?ref=dc122af897ab9a685c20ae54c639021619dbbb52).
- [P7: Module options](https://api.github.com/repos/Kyure-A/agent-skills-nix/contents/modules/common.nix?ref=dc122af897ab9a685c20ae54c639021619dbbb52) and [bundle implementation](https://api.github.com/repos/Kyure-A/agent-skills-nix/contents/lib/bundle.nix?ref=dc122af897ab9a685c20ae54c639021619dbbb52).
- [P8: flake-skills README](https://api.github.com/repos/papercomputeco/flake-skills/readme). HEAD observed as `18d23769c53d859ad59ec50e10e215ec16856f06`; README request was unpinned.
- [P9: skills-flake README](https://api.github.com/repos/bitbloxhub/skills-flake/readme). HEAD observed as `904f28412344e38a910f9260e1ea7636a22ecb88`; README request was unpinned.

Untested work includes a new input's evaluation and build on Darwin and Linux, library activation and deletion behavior, Pi discovery of a proposed link, and upstream script execution. No builds, package installation, skill execution, or activation ran. No configuration or lock file changed. The only repository write is this note.
