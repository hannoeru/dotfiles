# Better defaults
alias crontab="VIM_CRONTAB=true crontab"
alias diff="colordiff"
alias ag="rg"
alias vim="nvim"

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
alias d="nr dev"
alias b="nr build"
alias s="nr serve"
alias t="nr test"

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