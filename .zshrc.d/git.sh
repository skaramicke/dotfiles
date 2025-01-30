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
