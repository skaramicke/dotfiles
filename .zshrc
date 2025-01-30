#!/bin/zsh

function prepend() {
  local pattern=$1
  shift
  find . -type f -name "$pattern" -print0 | while IFS= read -r -d '' file; do
    # Create a temporary file for storing the new content
    {
      for line in "$@"; do
        echo "$line"
      done
      cat "$file"
    } >"$file.tmp" && mv "$file.tmp" "$file"
  done
}


function chpwd() {
  if [[ -f .zshrc.local ]]; then
    source .zshrc.local
  fi
  if [[ -f .nvmrc ]]; then
    nvm use
  fi
}

SCRIPT_LOCATION=$(dirname $0)
ZSHRCD=$SCRIPT_LOCATION/.zshrc.d
for file in $ZSHRCD/*.sh; do
  source $file
done
