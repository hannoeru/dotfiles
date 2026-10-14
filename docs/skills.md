# Managed skills

[`modules/home/skills.nix`](../modules/home/skills.nix) links the shared skill
catalogue into `~/.agents/skills/<category>/<name>`. Home Manager creates the
links from `home.file`. Activation does not download or install skills.

Remote entries are subdirectories of a `fetchFromGitHub` pin. Repo-local skills
live in [`home/skills`](../home/skills) and use the same category paths. To add
or change a skill, edit `skills.nix`: pin a repository (`rev` and `hash`) or
point a category path at a directory in `home/skills`.

Pi loads `~/.agents/skills` and `~/.pi/agent/skills`. This module uses the
first path. Pi walks category directories, so a second link is unnecessary.

The copies are read-only Nix store paths. `nix flake update` does not bump
remote pins; change those in `skills.nix`. Agents that read
`~/.agents/skills` discover the `SKILL.md` files on their next load.
