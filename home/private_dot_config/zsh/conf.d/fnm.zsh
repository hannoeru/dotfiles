# init fnm (node version manager)
if which fnm >/dev/null 2>&1; then
  eval "$(fnm env --use-on-cd --shell zsh --corepack-enabled)"
fi
