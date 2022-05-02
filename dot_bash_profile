# init homebrew
if [ $(uname) = "Darwin" ]; then
  if [ -e "/opt/homebrew/bin/brew" ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -e "/usr/local/bin/brew" ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# homebrew completions
if type brew &>/dev/null
then
  HOMEBREW_PREFIX="$(brew --prefix)"
  if [[ -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" ]]
  then
    source "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"
  else
    for COMPLETION in "${HOMEBREW_PREFIX}/etc/bash_completion.d/"*
    do
      [[ -r "${COMPLETION}" ]] && source "${COMPLETION}"
    done
  fi
fi

# Some OSes like Ubuntu/Mac expect bash_profile
# Redirect to bashrc
if [ -f ~/.bashrc ]; then
   source ~/.bashrc
fi
