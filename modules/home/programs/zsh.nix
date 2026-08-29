{ config, ... }:

{
  programs.zsh = {
    enable = true;
    dotDir = "${config.home.homeDirectory}/.config/zsh";
    initContent = ''
# History
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_SAVE_NO_DUPS
setopt INC_APPEND_HISTORY
setopt PUSHD_IGNORE_DUPS

# Move to directories without cd
setopt autocd

# Antidote plugin manager
function is-macos() { [[ $OSTYPE == darwin* ]] }
function is-linux() { [[ $OSTYPE == linux* ]] }

source $HOME/.antidote/antidote.zsh
antidote load ''${ZDOTDIR:-$HOME}/.zsh_plugins.txt

# Init zoxide
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# starship and mise are initialized by home-manager's zsh integrations

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
    '';
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
