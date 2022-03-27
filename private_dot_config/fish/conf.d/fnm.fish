if type -q fnm
  fnm env --use-on-cd | source
else
  echo 'You need to install fnm!'
end
