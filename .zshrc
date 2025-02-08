#!/bin/zsh

SCRIPT_LOCATION=$(dirname $0)
ZSHRCD=$SCRIPT_LOCATION/.zshrc.d
for file in $ZSHRCD/*.sh; do
  source $file
done
