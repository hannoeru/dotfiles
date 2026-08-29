if type -q starship
  starship init fish | source
else
  echo 'You need to install starship!'
end
