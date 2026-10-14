# Managed skills

[`modules/home/skills.nix`](../modules/home/skills.nix) links the shared skill
catalogue into `~/.agents/skills/<category>/<name>`. Home Manager creates the
links from `home.file`. Activation does not download or install skills.

Each entry is a subdirectory of a `fetchFromGitHub` pin. The directory name is
the skill name agents see. To add or change a skill, update that file: pin the
repository (`rev` and `hash`) and point a category path at the skill directory.

The copies are read-only Nix store paths. `nix flake update` does not bump
them; change the pin in `skills.nix`. Pi and other agents that read
`~/.agents/skills` discover the `SKILL.md` files on their next load.
