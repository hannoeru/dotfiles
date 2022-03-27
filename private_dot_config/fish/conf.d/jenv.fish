if type -q jenv
  set -Ux JENV_ROOT $HOME/.jenv
  set -U fish_user_paths $JENV_ROOT/bin $fish_user_paths

  status is-interactive; and source (jenv init -|psub)
else
  echo 'You need to install jenv!'
end
