# bin folder
fish_add_path "$HOME/bin"
# Custom scripts
fish_add_path "$HOME/.local/bin"
# curl
fish_add_path "$HOMEBREW_PREFIX/opt/curl/bin"
# openssl
fish_add_path "$HOMEBREW_PREFIX/opt/openssl/bin"
# libressl
fish_add_path "$HOMEBREW_PREFIX/opt/libressl/bin"
# grep
fish_add_path "$HOMEBREW_PREFIX/opt/grep/libexec/gnubin"
# sed
fish_add_path "$HOMEBREW_PREFIX/opt/gnu-sed/libexec/gnubin"
# awk
fish_add_path "$HOMEBREW_PREFIX/opt/gawk/libexec/gnubin"

#
# Node
#

# npm
fish_add_path "$HOME/.npm-global/bin"

# pnpm
set -gx PNPM_HOME "$HOME/Library/pnpm"
fish_add_path "$PNPM_HOME"

# simple-git-hooks
set -gx SIMPLE_GIT_HOOKS_RC="$HOME/.simple-git-hooks.rc"

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
fish_add_path "$ANDROID_HOME/tools/bin"

#
# bun
#

set -Ux BUN_INSTALL "/Users/hanlee/.bun"
fish_add_path "$HOME/.bun/bin"
