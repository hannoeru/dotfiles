# init miniconda
if [ -e $HOME/.pyenv/versions/miniconda3-latest/bin/conda ]; then
  eval "$('$HOME/.pyenv/versions/miniconda3-latest/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
fi
