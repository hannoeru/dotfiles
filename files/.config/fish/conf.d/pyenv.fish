if type -q pyenv
  set -Ux PYENV_ROOT $HOME/.pyenv
  fish_add_path "$PYENV_ROOT/bin"

  status is-login; and pyenv init --path | source
  status is-interactive; and pyenv init - | source
else
  echo 'You need to install pyenv!'
end
