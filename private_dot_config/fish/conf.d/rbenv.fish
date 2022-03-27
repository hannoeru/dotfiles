if type -q rbenv
  status --is-interactive; and rbenv init - fish | source
else
  echo 'You need to install rbenv!'
end
