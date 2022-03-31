if (uname) = "Darwin"
  if test -e "/opt/homebrew/bin/brew"
    eval (/opt/homebrew/bin/brew shellenv)
  else if test -e "/usr/local/bin/brew"
    eval (/usr/local/bin/brew shellenv)
  end
end

if type -q brew
  set -gx CPATH (brew --prefix)"/include"
  set -gx LIBRARY_PATH (brew --prefix)"/lib"
  set -gx LD_LIBRARY_PATH (brew --prefix)"/lib"

  if test -d (brew --prefix)"/share/fish/completions"
    set -gx fish_complete_path $fish_complete_path (brew --prefix)/share/fish/completions
  end

  if test -d (brew --prefix)"/share/fish/vendor_completions.d"
    set -gx fish_complete_path $fish_complete_path (brew --prefix)/share/fish/vendor_completions.d
  end
else
  echo "Please install 'brew' first!"
end

