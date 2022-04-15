# bin folder
fish_add_path "$HOME/bin"
# Custom scripts
fish_add_path "$HOME/.local/bin"
# OpenSSL
fish_add_path "$HOMEBREW_PREFIX/opt/openssl/bin"

#
# Node
#

# npm
fish_add_path "$HOME/.npm-global/bin"

# pnpm
set -gx PNPM_HOME "$HOME/Library/pnpm"
fish_add_path "$PNPM_HOME"

#
# Python
#

set -gx PYENV_ROOT "$HOME/.pyenv"
fish_add_path "$PYENV_ROOT/shims"

#
# Deno
#

set -gx DENO_DIR "$HOME/.deno"
fish_add_path "$HOME/.deno/bin"

#
# Golang
#

set -gx GOPATH "$HOME/go"
fish_add_path "$GOPATH/bin"

#
# Rust
#

set -gx CARGOPATH "$HOME/.cargo"
fish_add_path "$CARGOPATH/bin"

#
# Android
#

set -gx ANDROID_HOME "$HOME/Library/Android/sdk"
fish_add_path "$ANDROID_HOME/bin"
