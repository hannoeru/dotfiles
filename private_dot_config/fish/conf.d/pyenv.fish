if type -q pyenv
  set -Ux PYENV_ROOT $HOME/.pyenv
  set -U fish_user_paths $PYENV_ROOT/bin $fish_user_paths

  status is-login; and pyenv init --path | source
  status is-interactive; and pyenv init - | source
else
  echo 'You need to install pyenv!'
end
