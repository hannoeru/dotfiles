# env
set -gx BROWSER "open"

# alias
alias dl="cd ~/Downloads"
alias p="cd ~/Project"
alias wine="wine64"
alias brewup="brew update; brew upgrade; brew prune; brew cleanup"

if type -q exa
  alias l="exa -g --icons"
  alias ls="l"
  alias ll="l -l"
  alias lla="ll -a"
end
