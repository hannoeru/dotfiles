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

  # Tools managed by their home-manager modules (zsh, starship, gh, mise,
  # neovim, vim, ghostty) are not repeated here.
  sharedPackages = with pkgs; [
    eza
    ffmpeg
    git-filter-repo
    git-lfs
    jq
    kustomize
    nano
    ripgrep
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
  # mkDefault: as a nix-darwin module these come from users.users.<name>
  # (see modules/darwin.nix); standalone they are set here.
  home.username = lib.mkDefault machine.username;
  home.homeDirectory = lib.mkDefault (
    if darwin
    then "/Users/${machine.username}"
    else "/home/${machine.username}"
  );
  home.stateVersion = "25.05";

  home.packages = sharedPackages ++ lib.optionals darwin darwinPackages;

  imports = [
    ./programs/bash.nix
    ./programs/gh.nix
    ./programs/ghostty.nix
    ./programs/mise.nix
    ./programs/neovim.nix
    ./programs/starship.nix
    ./programs/vim.nix
    ./programs/zsh.nix
  ];

  home.file = {
    ".aliases".source = ../../files/.aliases;
    ".condarc".source = ../../files/.condarc;
    ".envfile".source = ../../files/.envfile;
    ".nanorc".source = ../../files/.nanorc;
    ".nirc".source = ../../files/.nirc;
    ".npmrc".source = ../../files/.npmrc;
    ".psqlrc".source = ../../files/.psqlrc;
    ".simple-git-hooks.rc".source = ../../files/.simple-git-hooks.rc;
    ".vuerc".source = ../../files/.vuerc;

    ".antidote".source = antidote;
    ".nano".source = nanorc;

    "bin" = {
      source = ../../files/bin;
      recursive = true;
    };

    ".pi" = {
      source = ../../files/.pi;
      recursive = true;
    };

    ".config/zsh/conf.d" = {
      source = ../../files/.config/zsh/conf.d;
      recursive = true;
    };
    ".config/zsh/.zsh_plugins.txt".source = ../../files/.config/zsh/.zsh_plugins.txt;
    ".config/fish" = {
      source = ../../files/.config/fish;
      recursive = true;
    };
    ".config/husky/init.sh".source = ../../files/.config/husky/init.sh;
    ".config/zsh-abbr/user-abbreviations".source = ../../files/.config/zsh-abbr/user-abbreviations;
  }
  // lib.optionalAttrs darwin {
    ".config/karabiner" = {
      source = ../../files/.config/karabiner;
      recursive = true;
    };
  }
  // lib.optionalAttrs machine.personal {
    ".ssh/config".source = ../../files/.ssh/config;
  };

  programs.git = {
    enable = true;
    # Written to ~/.config/git/ignore (git's default excludes file).
    ignores =[
        "# Folder view configuration files"
        ".DS_Store"
        "Desktop.ini"
        ""
        "# Thumbnail cache files"
        "._*"
        "Thumbs.db"
        ""
        "# Files that might appear on external disks"
        ".Spotlight-V100"
        ".Trashes"
        ""
        "# Compiled Python files"
        "*.pyc"
        ""
        "# Compiled C++ files"
        "*.out"
        ""
        "# Application specific files"
        "venv"
        "node_modules"
        ".sass-cache"
        ""
        "# AI stuff"
        ".pi-lens"
        ".pi-subagents"
        "**/.claude/settings.local.json"
      ];

    delta = {
      enable = true;
      options = {
        navigate = true;
        line-numbers = true;
      };
    };

    settings = {
      user = {
        name = machine.name;
        email = machine.email;
      };
      core = {
        editor = "code --wait";
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
    sshSetup = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.ssh/config.d"
      chmod 700 "$HOME/.ssh"
      if [ -f "$HOME/.ssh/config" ]; then
        chmod 600 "$HOME/.ssh/config"
      fi
    '';

    personalSecrets = lib.hm.dag.entryAfter [ "sshSetup" ] (
      if machine.personal then ''
        op_bin="$(command -v op || true)"
        if [ -z "$op_bin" ]; then
          for candidate in /opt/homebrew/bin/op "$HOME/.local/bin/op"; do
            if [ -x "$candidate" ]; then
              op_bin="$candidate"
              break
            fi
          done
        fi

        if [ -n "$op_bin" ] && "$op_bin" account get >/dev/null 2>&1; then
          $DRY_RUN_CMD mkdir -p "$HOME/.config/git"
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
            if [ -f "$HOME/.ssh/config.d/personal.conf" ]; then
              chmod 600 "$HOME/.ssh/config.d/personal.conf"
            fi
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
