if type -q fnm
  fnm env --version-file-strategy recursive --use-on-cd --corepack-enabled | source
else
  echo 'You need to install fnm!'
end
