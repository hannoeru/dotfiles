if type -q phpbrew
  if test -e "$HOME/.phpbrew/phpbrew.fish"
    source "$HOME/.phpbrew/phpbrew.fish"
  end
else
  echo 'You need to install phpbrew!'
end
