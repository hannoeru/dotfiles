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
    docker
    eza
    fzf
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

  sshSignProgram =
    if darwin then "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" else "op-ssh-sign";

  signingKeyRead =
    if machine ? sshSigningKeyItem then
      ''"$op_bin" item get '${machine.sshSigningKeyItem}' --format json | ${pkgs.jq}/bin/jq -r '.fields[] | select(.label == "public key") | .value' ''
    else
      null;

  findOnePasswordCli = ''
    op_bin="$(command -v op || true)"
    if [ -z "$op_bin" ]; then
      for candidate in /opt/homebrew/bin/op "$HOME/.local/bin/op"; do
        if [ -x "$candidate" ]; then
          op_bin="$candidate"
          break
        fi
      done
    fi
  '';
in
{
  # mkDefault: as a nix-darwin module these come from users.users.<name>
  # (see modules/darwin.nix); standalone they are set here.
  home.username = lib.mkDefault machine.username;
  home.homeDirectory = lib.mkDefault (
    if darwin then "/Users/${machine.username}" else "/home/${machine.username}"
  );
  home.stateVersion = "25.05";

  # The home-configuration manpage embeds options.json, whose build
  # triggers a Nix warning at eval time; read the docs online instead.
  manual.manpages.enable = false;

  home.packages = sharedPackages;

  home.sessionVariables = {
    DOCKER_BUILDKIT = "1";
    DENO_DIR = "$HOME/.deno";
    GOPATH = "$HOME/go";
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
    ./programs/git.nix
    ./programs/mise.nix
    ./programs/neovim.nix
    ./programs/starship.nix
    ./programs/vim.nix
    ./programs/vscode.nix
    ./programs/worktrunk.nix
    ./programs/zoxide.nix
    ./programs/zsh.nix
  ];

  home.file = {
    # Suppress the "Last login" message on interactive shells.
    ".hushlogin".text = "";

    ".aliases".source = ../../home/.aliases;
    ".envfile".source = ../../home/.envfile;
    ".nanorc".source = ../../home/.nanorc;
    ".nirc".source = ../../home/.nirc;
    ".npmrc".source = ../../home/.npmrc;
    ".psqlrc".source = ../../home/.psqlrc;
    ".simple-git-hooks.rc".source = ../../home/.simple-git-hooks.rc;

    ".nano".source = nanorc;

    ".pi" = {
      source = ../../home/.pi;
      recursive = true;
    };

    ".config/herdr/config.toml".source = ../../home/.config/herdr/config.toml;

    ".config/zsh/conf.d" = {
      source = ../../home/.config/zsh/conf.d;
      recursive = true;
    };
    # Both git-hook tools run `mise activate bash`; one shared source.
    ".config/husky/init.sh".source = ../../home/.simple-git-hooks.rc;
    ".config/zsh-abbr/user-abbreviations".source = ../../home/.config/zsh-abbr/user-abbreviations;
  }
  // lib.optionalAttrs darwin {
    ".config/karabiner" = {
      source = ../../home/.config/karabiner;
      recursive = true;
    };

    # The 1Password SSH agent socket path is macOS-specific, so it
    # cannot live in the shared ~/.ssh/config that Linux boxes use.
    ".ssh/config.d/10-agent.conf".text = ''
      Host *
        IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    '';
  }
  // lib.optionalAttrs machine.personal {
    ".ssh/config".source = ../../home/.ssh/config;
  };

  home.activation = {
    sshSetup = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      $DRY_RUN_CMD mkdir -p "$HOME/.ssh"
      $DRY_RUN_CMD chmod 700 "$HOME/.ssh"
      $DRY_RUN_CMD mkdir -p "$HOME/.ssh/config.d"
      $DRY_RUN_CMD chmod 700 "$HOME/.ssh/config.d"
    '';

    signingKey = lib.hm.dag.entryAfter [ "sshSetup" ] (
      if signingKeyRead != null then
        ''
          if [[ -v DRY_RUN ]]; then
            echo "Would update $HOME/.config/git/signing.gitconfig from 1Password"
          else
            ${findOnePasswordCli}
            if [ -n "$op_bin" ] && "$op_bin" account get >/dev/null 2>&1; then
              mkdir -p "$HOME/.config/git"
              key="$(${signingKeyRead} || true)"
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
                mv "$tmp" "$HOME/.config/git/signing.gitconfig"
              else
                echo "warning: could not fetch git signing key from 1Password" >&2
              fi
            else
              echo "warning: 1Password CLI not available, skipped git signing key" >&2
            fi
          fi
        ''
      else
        ""
    );

    personalSshConfig = lib.hm.dag.entryAfter [ "sshSetup" ] (
      if machine.personal then
        ''
          if [[ -v DRY_RUN ]]; then
            echo "Would update $HOME/.ssh/config.d/personal.conf from 1Password"
          else
            ${findOnePasswordCli}
            if [ -n "$op_bin" ] && "$op_bin" account get >/dev/null 2>&1; then
              tmp="$(mktemp)"
              if "$op_bin" document get lqhaym7u7wa5jjfpcmenk7xo4y > "$tmp"; then
                mv "$tmp" "$HOME/.ssh/config.d/personal.conf"
                chmod 600 "$HOME/.ssh/config.d/personal.conf"
              else
                rm -f "$tmp"
                echo "warning: could not fetch ssh config from 1Password" >&2
              fi
            else
              echo "warning: 1Password CLI not available, skipped personal ssh config" >&2
            fi
          fi
        ''
      else
        ""
    );

    # Pi extensions resolve runtime dependencies from ~/.pi/node_modules at
    # load time. That directory is not part of the nix-store .pi copy (the
    # source links file-by-file), so materialize it after links are generated.
    piNodeModules = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -x "${pkgs.pnpm}/bin/pnpm" ] && [ -s "$HOME/.pi/pnpm-lock.yaml" ]; then
        $DRY_RUN_CMD "${pkgs.pnpm}/bin/pnpm" --dir "$HOME/.pi" install --frozen-lockfile --ignore-scripts >/dev/null 2>&1 \
          || echo "warning: pnpm install in ~/.pi failed; pi extensions may not load runtime deps" >&2
      fi
    '';
  };
}
