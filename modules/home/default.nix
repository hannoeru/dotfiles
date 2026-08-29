# Shared home-manager configuration for all machines.
# Machine facts come from machines.nix via the `machine` module argument.
{
  config,
  pkgs,
  lib,
  machine,
  nanorc,
  ...
}:

let
  darwin = machine.os == "darwin";

  # Tools managed by their home-manager modules (zsh, starship, gh, mise,
  # neovim, vim, ghostty, zoxide, bash) are not repeated here.
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
    zsh-completions
  ];

  darwinPackages = with pkgs; [
    awscli2
    azure-cli
    docker
    opentofu
  ];

  sshSignProgram =
    if darwin then "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" else "op-ssh-sign";
in
{
  # mkDefault: as a nix-darwin module these come from users.users.<name>
  # (see modules/darwin.nix); standalone they are set here.
  home.username = lib.mkDefault machine.username;
  home.homeDirectory = lib.mkDefault (
    if darwin then "/Users/${machine.username}" else "/home/${machine.username}"
  );
  home.stateVersion = "25.05";

  home.packages = sharedPackages ++ lib.optionals darwin darwinPackages;

  home.sessionVariables = {
    DOCKER_BUILDKIT = "1";
    DENO_DIR = "$HOME/.deno";
    GOPATH = "$HOME/go";
    CARGOPATH = "$HOME/.cargo";
    SIMPLE_GIT_HOOKS_RC = "$HOME/.simple-git-hooks.rc";
  }
  // lib.optionalAttrs darwin {
    PNPM_HOME = "$HOME/Library/pnpm";
    ANDROID_HOME = "$HOME/Library/Android/sdk";
  };

  home.sessionPath = [
    "$HOME/bin"
    "$HOME/.local/bin"
    "$HOME/.npm-global/bin"
    "$HOME/.deno/bin"
    "$HOME/go/bin"
    "$HOME/.cargo/bin"
  ]
  ++ lib.optionals darwin [
    "$HOME/Library/pnpm/bin"
    "$HOME/Library/Android/sdk/tools/bin"
  ];

  imports = [
    ./programs/bash.nix
    ./programs/gh.nix
    ./programs/ghostty.nix
    ./programs/mise.nix
    ./programs/neovim.nix
    ./programs/starship.nix
    ./programs/vim.nix
    ./programs/zoxide.nix
    ./programs/zsh.nix
  ];

  home.file = {
    ".aliases".source = ../../files/.aliases;
    ".envfile".source = ../../files/.envfile;
    ".nanorc".source = ../../files/.nanorc;
    ".nirc".source = ../../files/.nirc;
    ".npmrc".source = ../../files/.npmrc;
    ".psqlrc".source = ../../files/.psqlrc;
    ".simple-git-hooks.rc".source = ../../files/.simple-git-hooks.rc;

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
    ignores = [
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

    # ~/.config/git/signing.gitconfig is written by
    # home.activation.personalSecrets when 1Password is available; git
    # silently ignores missing include files.
    includes = [
      { path = "~/.config/git/signing.gitconfig"; }
      {
        path = "~/projects/.gitconfig";
        condition = "gitdir:~/projects/";
      }
    ];

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
      $DRY_RUN_CMD chmod 700 "$HOME/.ssh"
    '';

    personalSecrets = lib.hm.dag.entryAfter [ "sshSetup" ] (
      if machine.personal then
        ''
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
                $DRY_RUN_CMD chmod 600 "$HOME/.ssh/config.d/personal.conf"
              fi
            else
              rm -f "$tmp"
              echo "warning: could not fetch ssh config from 1Password" >&2
            fi
          else
            echo "warning: 1Password CLI not available, skipped personal secrets" >&2
          fi
        ''
      else
        ""
    );
  };
}
