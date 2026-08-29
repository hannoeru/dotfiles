# History
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_SAVE_NO_DUPS
setopt INC_APPEND_HISTORY
setopt PUSHD_IGNORE_DUPS

# Move to directories without cd
setopt autocd

# Completions from nix-managed packages (standalone home-manager and
# nix-darwin module layouts use different prefixes).
for fdir in "$HOME/.nix-profile/share/zsh/site-functions" "/etc/profiles/per-user/$USER/share/zsh/site-functions"; do
  [ -d "$fdir" ] && fpath=("$fdir" $fpath)
done

# Antidote plugin manager
function is-macos() { [[ $OSTYPE == darwin* ]] }
function is-linux() { [[ $OSTYPE == linux* ]] }

source $HOME/.antidote/antidote.zsh
antidote load ${ZDOTDIR:-$HOME}/.zsh_plugins.txt

# Init zoxide
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# Init starship prompt
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

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
