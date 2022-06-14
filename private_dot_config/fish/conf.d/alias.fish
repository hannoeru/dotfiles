# Changing/making/removing directory
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."

alias 1="cd -1"
alias 2="cd -2"
alias 3="cd -3"
alias 4="cd -4"
alias 5="cd -5"
alias 6="cd -6"
alias 7="cd -7"
alias 8="cd -8"
alias 9="cd -9"

alias md="mkdir -p"
alias rd="rmdir"

# Better defaults
alias crontab="VIM_CRONTAB=true crontab"
alias diff="colordiff"
alias ag="rg"
alias vim="nvim"
alias git="hub"

# ssh
alias sshlink="ssh-copy-id -i ~/.ssh/id_rsa.pub"
alias sshconfig="nano ~/.ssh/config"

# basic
alias up="cd ../"
alias la="ls -a"
alias lla="ls -al"
alias l="ls"
alias dotfiles="chezmoi cd"

# pnpm
alias npx="pnpm dlx"
alias u="pnpm update"
alias nad="pnpm add -D"
alias na="pnpm add"
alias pnpmu="pnpm i -g pnpm"

# update npm deps
alias udeps="taze major -rwu"

# npm run
alias s="nr start"
alias d="nr dev"
alias b="nr build"
alias bw="nr build --watch"
alias t="nr test"
alias tu="nr test -u"
alias tw="nr test --watch"
alias w="nr watch"
alias p="nr preview"
alias tc="nr type-check"
alias lint="nr lint"
alias lintf="nr lint --fix"
alias release="nr release"
alias re="nr release"
alias sb="nr storybook"

# vite
alias cva="pnpm dlx create-vite"

# docker
alias dsa="docker ps -q | xargs docker stop"
alias drma="docker ps -q | xargs docker rm"
alias drmia="docker images -q | xargs docker rmi"

# docker compose
alias dc="docker compose"
alias dce="docker compose exec"
alias dcl="docker compose logs"
alias dcps="docker compose ps"
alias dcup="docker compose up -d"
alias dcd="docker compose down"
alias dcb="docker compose build"
alias dckill="docker compose kill"
alias docker-compose="docker compose"

# python
alias py="python"
alias prp="pipenv run python"
alias ps="pipenv shell"
alias pi="pipenv install"
alias pu="pipenv uninstall"
alias pg="pipenv graph"
alias prm="pipenv --rm"

# github
alias pr="gh pr checkout"
