{ ... }:

{
  programs.bash = {
    enable = true;

    profileExtra = ''
      # Homebrew environment and completions (login shells)
      if [ $(uname) = "Darwin" ]; then
        if [ -e "/opt/homebrew/bin/brew" ]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -e "/usr/local/bin/brew" ]; then
          eval "$(/usr/local/bin/brew shellenv)"
        fi
      fi

      if type brew &>/dev/null; then
        HOMEBREW_PREFIX="$(brew --prefix)"
        if [[ -r "''${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]; then
          source "''${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
        else
          for COMPLETION in "''${HOMEBREW_PREFIX}/etc/bash_completion.d/"*; do
            [[ -r "$COMPLETION" ]] && source "$COMPLETION"
          done
        fi
      fi
    '';

    bashrcExtra = ''
      if [ -f ~/.envfile ]; then
        source ~/.envfile
      fi

      if [ -f ~/.aliases ]; then
        source ~/.aliases
      fi
    '';
  };
}
