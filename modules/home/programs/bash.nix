{ ... }:

{
  programs.bash = {
    enable = true;

    profileExtra = ''
      # Homebrew environment (login shells); the real consumers of this
      # profile are non-interactive git hooks, so completions are not needed.
      if [ $(uname) = "Darwin" ]; then
        if [ -e "/opt/homebrew/bin/brew" ]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -e "/usr/local/bin/brew" ]; then
          eval "$(/usr/local/bin/brew shellenv)"
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
