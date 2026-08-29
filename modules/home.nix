# Shared home-manager configuration for all machines.
#
# `machine` describes the target machine:
#   os       - "darwin" or "linux"
#   username - login name
#   personal - whether this machine may read personal secrets from 1Password
#   name     - git user name
#   email    - git user email
machine:
{ config, pkgs, lib, antidote, nanorc, ... }:

let
  darwin = machine.os == "darwin";

  sharedPackages = with pkgs; [
    eza
    ffmpeg
    delta
    gh
    git-filter-repo
    git-lfs
    jq
    kustomize
    mise
    nano
    neovim
    ripgrep
    starship
    tmux
    unzip
    wget
    zoxide
    zsh-completions
  ];

  darwinPackages = with pkgs; [
    awscli2
    azure-cli
    docker
    opentofu
  ];

  sshSignProgram =
    if darwin
    then "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
    else "op-ssh-sign";
in
{
  home.username = machine.username;
  home.homeDirectory =
    if darwin
    then "/Users/${machine.username}"
    else "/home/${machine.username}";
  home.stateVersion = "25.05";

  home.packages = sharedPackages ++ lib.optionals darwin darwinPackages;

  home.file = {
    ".aliases".source = ../files/.aliases;
    ".bash_profile".source = ../files/.bash_profile;
    ".bashrc".source = ../files/.bashrc;
    ".condarc".source = ../files/.condarc;
    ".envfile".source = ../files/.envfile;
    ".nanorc".source = ../files/.nanorc;
    ".nirc".source = ../files/.nirc;
    ".npmrc".source = ../files/.npmrc;
    ".psqlrc".source = ../files/.psqlrc;
    ".simple-git-hooks.rc".source = ../files/.simple-git-hooks.rc;
    ".tmux.conf".source = ../files/.tmux.conf;
    ".tmux-osx.conf".source = ../files/.tmux-osx.conf;
    ".vimrc".source = ../files/.vimrc;
    ".vuerc".source = ../files/.vuerc;
    ".zshenv".source = ../files/.zshenv;

    ".antidote".source = antidote;
    ".nano".source = nanorc;

    ".ssh/config".source = ../files/.ssh/config;

    "bin" = {
      source = ../files/bin;
      recursive = true;
    };

    ".pi" = {
      source = ../files/.pi;
      recursive = true;
    };

    ".config/zsh" = {
      source = ../files/.config/zsh;
      recursive = true;
    };
    ".config/fish" = {
      source = ../files/.config/fish;
      recursive = true;
    };
    ".config/git/ignore".source = ../files/.config/git/ignore;
    ".config/ghostty" = {
      source = ../files/.config/ghostty;
      recursive = true;
    };
    ".config/gh/config.yml".source = ../files/.config/gh/config.yml;
    ".config/husky/init.sh".source = ../files/.config/husky/init.sh;
    ".config/mise/config.toml".source = ../files/.config/mise/config.toml;
    ".config/nvim/init.vim".source = ../files/.config/nvim/init.vim;
    ".config/starship.toml".source = ../files/.config/starship.toml;
    ".config/zsh-abbr/user-abbreviations".source = ../files/.config/zsh-abbr/user-abbreviations;
  }
  // lib.optionalAttrs darwin {
    ".config/karabiner" = {
      source = ../files/.config/karabiner;
      recursive = true;
    };
  };

  programs.git = {
    enable = true;
    userName = machine.name;
    userEmail = machine.email;

    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
      };
    };

    extraConfig = {
      core = {
        editor = "code --wait";
        excludesfile = "~/.config/git/ignore";
        autocrlf = "input";
        safecrlf = true;
      };
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      init.defaultBranch = "main";
      diff = {
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };
      "split-diffs".theme-name = "github-dark-dim";
      merge.conflictstyle = "zdiff3";
      pull.rebase = true;
      push = {
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };
      fetch = {
        prune = true;
        pruneTags = true;
        all = true;
      };
      help.autocorrect = "prompt";
      commit.verbose = true;
      rerere = {
        enabled = true;
        autoupdate = true;
      };
      rebase = {
        autosquash = true;
        autostash = true;
        updateRefs = true;
      };
      credential."https://dev.azure.com".useHttpPath = true;
      url."https://github.com/".insteadOf = "git@github.com:";
      hub.protocol = "https";
      # Written by home.activation.personalSecrets when 1Password is available.
      include.path = "~/.config/git/signing.gitconfig";
      includeIf."gitdir:~/projects/".path = "~/projects/.gitconfig";
      filter.lfs = {
        process = "git-lfs filter-process";
        required = true;
        clean = "git-lfs clean -- %f";
        smudge = "git-lfs smudge -- %f";
      };
      alias = {
        co = "checkout";
        ci = "commit";
        st = "status";
        br = "branch";
        hist = "log --pretty=format:'%h %ad | %s%d [%an]' --graph --date=short";
        type = "cat-file -t";
        dump = "cat-file -p";
        ac = "commit -am";
        fpush = "push --force-with-lease";
      };
    };
  };

  home.activation = {
    sshSetup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.ssh/config.d"
      chmod 700 "$HOME/.ssh"
      chmod 600 "$HOME/.ssh/config"
    '';

    personalSecrets = lib.hm.dag.entryAfter [ "sshSetup" ] (
      if machine.personal then ''
        op_bin="$(command -v op || true)"
        if [ -z "$op_bin" ] && [ -x /opt/homebrew/bin/op ]; then
          op_bin=/opt/homebrew/bin/op
        fi

        if [ -n "$op_bin" ] && "$op_bin" account get >/dev/null 2>&1; then
          key="$($op_bin read 'op://Private/GitHub SSH Key/public key' || true)"
          if [ -n "$key" ]; then
            tmp="$(mktemp)"
            {
              echo "[user]"
              echo "  signingkey = $key"
              echo "[commit]"
              echo "  gpgsign = true"
              echo "[gpg]"
              echo "  format = ssh"
              echo "[gpg \"ssh\"]"
              echo "  program = ${sshSignProgram}"
            } > "$tmp"
            $DRY_RUN_CMD mv "$tmp" "$HOME/.config/git/signing.gitconfig"
          else
            echo "warning: could not fetch git signing key from 1Password" >&2
          fi

          tmp="$(mktemp)"
          if "$op_bin" document lqhaym7u7wa5jjfpcmenk7xo4y > "$tmp"; then
            $DRY_RUN_CMD mv "$tmp" "$HOME/.ssh/config.d/personal.conf"
            chmod 600 "$HOME/.ssh/config.d/personal.conf"
          else
            rm -f "$tmp"
            echo "warning: could not fetch ssh config from 1Password" >&2
          fi
        else
          echo "warning: 1Password CLI not available, skipped personal secrets" >&2
        fi
      '' else ""
    );
  };
}
