# alt + arrow key to move
bindkey "^[[1;3C" forward-word
bindkey "^[[1;3D" backward-word
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey "\e\eOC" forward-word
bindkey "\e\eOD" backward-word
bindkey "\e\e[C" forward-word
bindkey "\e\e[D" backward-word

# Up/Down keys for searching history
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "\e\eA" up-line-or-beginning-search
bindkey "\e\eB" down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search
bindkey "^[OA" up-line-or-beginning-search
bindkey "^[OB" down-line-or-beginning-search

bindkey "^N" forward-word
bindkey "^P" backward-word
bindkey "^B" backward-kill-word
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^R' history-incremental-search-backward
bindkey "\e\e^H" backward-kill-word # Alt + Backspace
bindkey "^[^?" backward-kill-word # Alt + Backspace
bindkey "\e\C-?" backward-kill-word # Alt + Backspace
bindkey "^Z" undo
bindkey "^Y" redo
bindkey "^V" PasteFromClipboard # Ctrl V to paste from Clipboard.txt
bindkey "^X" CutToClipboard # Ctrl X to cut to Clipboard.txt
bindkey "^G" FindFilesToExec # Ctrl G to execute command on multiple files
bindkey "^F" Forever # Ctrl F to run a command Forever
bindkey "^O" OpenFileExplorer # Ctrl O to open file explorer here
