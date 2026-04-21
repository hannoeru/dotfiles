# zsh-syntax-highlighting custom styles
# Since the plugin is deferred, set styles via precmd hook after it loads
_apply_syntax_styles() {
  if (( $+functions[_zsh_highlight] )); then
    autoload -Uz add-zsh-hook
    add-zsh-hook -d precmd _apply_syntax_styles

    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern line)
    ZSH_HIGHLIGHT_STYLES[default]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[path]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=cyan'
    ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=red'
    ZSH_HIGHLIGHT_STYLES[redirection]='fg=red'
    ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=red'
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=red'
    ZSH_HIGHLIGHT_STYLES[globbing]='fg=blue'
    ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=blue'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=blue'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=blue'
    ZSH_HIGHLIGHT_STYLES[command]='fg=blue'
    ZSH_HIGHLIGHT_STYLES[precommand]='fg=blue'
    ZSH_HIGHLIGHT_STYLES[function]='fg=blue'
    ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=blue'
    ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=blue'
    ZSH_HIGHLIGHT_STYLES[assign]='fg=yellow'
    ZSH_HIGHLIGHT_STYLES[arg0]='fg=yellow'
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=yellow'
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=yellow'
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=yellow'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=yellow'
    ZSH_HIGHLIGHT_STYLES[comment]='fg=gray'
  fi
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _apply_syntax_styles
