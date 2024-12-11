#!/bin/zsh

function git-prune() {
  default_branch=$(git remote show origin | sed -n '/HEAD branch/s/.*: //p')
  git fetch origin
  git checkout $default_branch
  git reset --hard "origin/$default_branch"
  git branch | grep -v "\*" | xargs -n 1 git branch -D
}

function feature() {
  git-prune
  git checkout -b feature/$1 develop
}

function killport() {
  lsof -i TCP:$1 | grep LISTEN | awk '{print $2}' | xargs kill -9
}

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

port() { 
  if [ -z "$1" ]; then 
    echo "Usage: port <port_number>" 
    return 1 
  fi

  sudo lsof -i :"$1" | grep LISTEN | awk '{print $2}' | while read -r pid; do
    command=$(ps -p "$pid" -o comm=)
    echo "PID: $pid, Command: $command"
  done
}

yq e '.contexts[].name' ~/.kube/config | while read -r cluster; do
  alias $cluster="kubectl --context $cluster"
done

function chpwd() {
    if [[ -f .zshrc.local ]]; then
        source .zshrc.local
    fi
    if [[ -f .nvmrc ]]; then
        nvm use
    fi
}
