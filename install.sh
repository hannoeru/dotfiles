#!/bin/sh

set -e # -e: exit on error

# install homebrew
if [ ! "$(command -v brew)" ]; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# install chezmoi
if [ ! "$(command -v chezmoi)" ]; then
  brew install chezmoi
fi

# POSIX way to get script's dir: https://stackoverflow.com/a/29834779/12156188
script_dir="$(cd -P -- "$(dirname -- "$(command -v -- "$0")")" && pwd -P)"
# exec: replace current process with chezmoi init
exec chezmoi init --apply "--source=$script_dir"
