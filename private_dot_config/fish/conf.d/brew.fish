eval (/opt/homebrew/bin/brew shellenv)

if type -q brew
  set -gx CPATH "/opt/homebrew/include"
  set -gx LIBRARY_PATH "/opt/homebrew/lib"
  set -gx LD_LIBRARY_PATH "/opt/homebrew/lib"

  if test -d (brew --prefix)"/share/fish/completions"
    set -gx fish_complete_path $fish_complete_path (brew --prefix)/share/fish/completions
  end

  if test -d (brew --prefix)"/share/fish/vendor_completions.d"
    set -gx fish_complete_path $fish_complete_path (brew --prefix)/share/fish/vendor_completions.d
  end
else
  echo "Please install 'brew' first!"
end

