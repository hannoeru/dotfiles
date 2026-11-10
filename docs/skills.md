# Managed skills

[`modules/home/skills.nix`](../modules/home/skills.nix) links the shared skill
catalogue into `~/.agents/skills/<category>/<name>`. Home Manager creates the
links from `home.file`. Activation does not download or install skills.

Remote entries are subdirectories of a `flake = false` input in
[`flake.nix`](../flake.nix). Skills authored for every machine live in
[`home/skills`](../home/skills) and use the same category paths. To add a
remote skill, add an input, list it in `skillInputs` in `flake.nix` and in
`skills.nix`, and point a category path at its subdirectory. To add a
repository skill, point a category path at a directory in `home/skills`.

`Writing/bro` is the upstream skill from the pinned `cursor/plugins` checkout
at `pstack/skills/bro`, the same pin as `Writing/unslop`. The `home.file` link
is `~/.agents/skills/Writing/bro`. This repository does not keep a copy.

`Terminal/herdr` is the upstream skill from the pinned `herdrdev/herdr`
checkout at `skills/herdr`. The `home.file` link is
`~/.agents/skills/Terminal/herdr`. This repository does not keep a copy.

Repository skills linked from `home/skills`:

| Category path | Directory |
| --- | --- |
| `Workflow/analyze-issue` | `home/skills/analyze-issue` |
| `Workflow/create-pr` | `home/skills/create-pr` |
| `Workflow/deslop` | `home/skills/deslop` |
| `Workflow/review-pr` | `home/skills/review-pr` |
| `Workflow/wrap-up` | `home/skills/wrap-up` |
| `Vue & Nuxt/nuxt-cloudflare` | `home/skills/nuxt-cloudflare` |

Home Manager does not install `~/.pi/agent/prompts`.

The `antfu` pin provides `Workflow/antfu`.

Pi loads `~/.agents/skills` and `~/.pi/agent/skills`. This module uses the
first path. Pi walks category directories, so a second link is unnecessary.

The copies are read-only Nix store paths. `flake.lock` holds the revision of
each GitHub input, and `nix flake update` updates them. The URL of the `pstack`
input holds its version; change the URL to update it. Pi installs the pstack
package itself from `~/.pi/agent/settings.json`, which pins the same version as
`npm:@zenspc/pi-pstack@<version>`. Change both versions together, so that the
preloaded Poteto Mode text matches the installed extension. Agents that read
`~/.agents/skills` discover the `SKILL.md` files on their next load.

`verify-dotfiles` is not in this catalogue. It verifies this repository only
and lives at
[`.agents/skills/verify-dotfiles`](../.agents/skills/verify-dotfiles/SKILL.md).
Home Manager does not link it into `~/.agents/skills`. Agents that open this
checkout read it from that path. Its feature map stays beside `SKILL.md`, so
the `features/` links inside the skill still resolve.
