# env
set -gx BROWSER "open"

# alias
alias dl="cd ~/Downloads"
alias p="cd ~/Projects"
alias forks="cd ~/Projects/forks"
alias wine="wine64"
alias brewup="brew update; brew upgrade; brew cleanup"

if type -q eza
  alias l="eza -g --icons"
  alias ls="l"
  alias ll="l -l"
  alias lla="ll -a"
end
