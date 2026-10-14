# Managed skills

[`modules/home/skills.nix`](../modules/home/skills.nix) links the shared skill
catalogue into `~/.agents/skills/<category>/<name>`. Home Manager creates the
links from `home.file`. Activation does not download or install skills.

Remote entries are subdirectories of a `fetchFromGitHub` pin. Skills authored
for every machine live in [`home/skills`](../home/skills) and use the same
category paths. To add or change one of those skills, edit `skills.nix`: pin a
repository (`rev` and `hash`) or point a category path at a directory in
`home/skills`.

Pi loads `~/.agents/skills` and `~/.pi/agent/skills`. This module uses the
first path. Pi walks category directories, so a second link is unnecessary.

The copies are read-only Nix store paths. `nix flake update` does not bump
remote pins; change those in `skills.nix`. Agents that read
`~/.agents/skills` discover the `SKILL.md` files on their next load.

`verify-dotfiles` is not in this catalogue. It verifies this repository only
and lives at
[`.agents/skills/verify-dotfiles`](../.agents/skills/verify-dotfiles/SKILL.md).
Home Manager does not link it into `~/.agents/skills`. Agents that open this
checkout read it from that path. Its feature map stays beside `SKILL.md`, so
the `features/` links inside the skill still resolve.
