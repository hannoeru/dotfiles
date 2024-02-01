# disable welcome message
set fish_greeting ""

set -gx TERM xterm-256color

# theme
set -g fish_prompt_pwd_dir_length 0

function fish_title
  set -q argv[1]; or set argv fish
  echo (prompt_pwd): $argv;
end

# editors
# Preferred editor for local and remote sessions
if test -n $SSH_CONNECTION
  set -gx EDITOR "vim"
else
  if type -q code
    set -gx EDITOR "code --wait"
  else
    set -gx EDITOR "nano"
  end
end

# default tools
set -gx VISUAL "nano"
set -gx PAGER "less"

# language
if test -z "$LANG"
  set -gx LANG "en_US.UTF-8"
end

# default colors
set -gx CLICOLOR 1
set -gx LS_COLORS gxBxhxDxfxhxhxhxhxcxcx

# less
set -gx LESS "-F -g -i -M -R -S -w -X -z-4"

# load OS specific configs
switch (uname)
  case Darwin
    source (dirname (status --current-filename))/config-osx.fish
end
