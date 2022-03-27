# bin folder
add_to_path "$HOME/bin"
# Custom scripts
add_to_path "$HOME/.local/bin"
# OpenSSL
add_to_path "$HOMEBREW_PREFIX/opt/openssl/bin"

#
# Node
#

add_to_path "./node_modules/.bin"

#
# PHP
#

# if test -d "$HOME/.phpbrew"
#   source "$HOME/.phpbrew/phpbrew.fish"
# end

#
# Python
#

set -gx PYENV_ROOT "$HOME/.pyenv"
add_to_path "$PYENV_ROOT/shims"

#
# Deno
#

set -gx DENO_DIR "$HOME/.deno"
add_to_path "$HOME/.deno/bin"

#
# Golang
#

set -gx GOPATH "$HOME/go"
add_to_path "$GOPATH/bin"

#
# Rust
#

set -gx CARGOPATH "$HOME/.cargo"
add_to_path "$CARGOPATH/bin"

#
# Android
#

set -gx ANDROID_HOME "$HOME/Library/Android/sdk"
add_to_path "$ANDROID_HOME/bin"
