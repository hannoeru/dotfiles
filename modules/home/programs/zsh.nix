{ config, lib, ... }:

{
  programs.zsh = {
    enable = true;
    dotDir = "${config.home.homeDirectory}/.config/zsh";

    history = {
      path = "$HOME/.zsh_history";
      size = 100000;
      save = 100000;
      saveNoDups = true;
    };

    antidote = {
      enable = true;
      plugins = [
        "romkatv/zsh-defer"
        "getantidote/use-omz"
        "ohmyzsh/ohmyzsh path:lib"
        "ohmyzsh/ohmyzsh path:plugins/brew conditional:is-macos"
        "ohmyzsh/ohmyzsh path:plugins/macos conditional:is-macos"
        "ohmyzsh/ohmyzsh path:plugins/kubectl kind:defer"
        "olets/zsh-abbr kind:defer"
        "olets/zsh-job-queue kind:defer"
        "zsh-users/zsh-autosuggestions kind:defer"
        "zsh-users/zsh-history-substring-search kind:defer"
      ];
    };

    syntaxHighlighting = {
      enable = true;
      highlighters = [
        "brackets"
        "pattern"
        "line"
      ];
      styles = {
        default = "fg=cyan";
        single-hyphen-option = "fg=cyan";
        double-hyphen-option = "fg=cyan";
        dollar-quoted-argument = "fg=cyan";
        dollar-double-quoted-argument = "fg=blue";
        back-double-quoted-argument = "fg=cyan";
        back-dollar-quoted-argument = "fg=cyan";
        path = "fg=cyan";
        path_pathseparator = "fg=cyan";
        path_prefix = "fg=cyan";
        path_prefix_pathseparator = "fg=cyan";
        reserved-word = "fg=red";
        redirection = "fg=red";
        commandseparator = "fg=red";
        unknown-token = "fg=red";
        globbing = "fg=blue";
        builtin = "fg=blue";
        alias = "fg=blue";
        command = "fg=blue";
        precommand = "fg=blue";
        function = "fg=blue";
        hashed-command = "fg=blue";
        suffix-alias = "fg=blue";
        assign = "fg=yellow";
        arg0 = "fg=yellow";
        back-quoted-argument = "fg=yellow";
        back-quoted-argument-unclosed = "fg=yellow";
        single-quoted-argument = "fg=yellow";
        double-quoted-argument = "fg=yellow";
        comment = "fg=gray";
      };
    };

    initContent = lib.mkMerge [
      (lib.mkOrder 500 ''
        # conditionals used by the antidote plugin bundle
        function is-macos() { [[ $OSTYPE == darwin* ]] }
        function is-linux() { [[ $OSTYPE == linux* ]] }
      '')

      (lib.mkOrder 600 ''
        # not covered by programs.zsh.history
        setopt INC_APPEND_HISTORY
        setopt PUSHD_IGNORE_DUPS

        # Move to directories without cd
        setopt autocd

        # Load custom configs
        for file in $HOME/.config/zsh/conf.d/*.zsh; do
          [ -r "$file" ] && source "$file"
        done

        # Load aliases
        if [ -f ~/.aliases ]; then
          source ~/.aliases
        fi

        # Deduplicate paths
        typeset -gU cdpath fpath mailpath path
      '')
    ];

    profileExtra = ''
      # init homebrew
      if [ $(uname) = "Darwin" ]; then
        if [ -e "/opt/homebrew/bin/brew" ]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -e "/usr/local/bin/brew" ]; then
          eval "$(/usr/local/bin/brew shellenv)"
        fi
      fi

      # export HOMEBREW_NO_ENV_HINTS=true
      if type brew &>/dev/null; then
        FPATH="$(brew --prefix)/share/zsh/site-functions:''${FPATH}"
      fi

      # better defaults
      if [ $(uname) = "Darwin" ]; then
        export BROWSER='open'
      fi

      # Preferred editor for local and remote sessions
      if [[ -n $SSH_CONNECTION ]]; then
        export EDITOR='vim'
      else
        if type code >/dev/null 2>&1; then
          export EDITOR='code --wait'
        else
          export EDITOR='nano'
        fi
      fi

      export VISUAL='nano'
      export PAGER='less'

      # Language
      if [ -z "$LANG" ]; then
        export LANG='en_US.UTF-8'
      fi

      # CLI colors
      export CLICOLOR=1
      export LSCOLORS=gxBxhxDxfxhxhxhxhxcxcx

      # Set the default Less options.
      export LESS='-F -g -i -M -R -S -w -X -z-4'
      # Set the Less input preprocessor.
      # Try both `lesspipe` and `lesspipe.sh` as either might exist on a system.
      if (( $#commands[(i)lesspipe(|.sh)] )); then
        export LESSOPEN="| /usr/bin/env $commands[(i)lesspipe(|.sh)] %s 2>&-"
      fi

      # Environment setup
      if [ -f ~/.envfile ]; then
        source ~/.envfile
      fi
    '';
  };
}
