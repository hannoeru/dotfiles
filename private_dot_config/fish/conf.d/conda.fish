if test -e $HOME/.pyenv/versions/miniconda3-latest/bin/conda
  eval $HOME/.pyenv/versions/miniconda3-latest/bin/conda "shell.fish" "hook" $argv | source
else
  echo 'You need to install miniconda!'
end
