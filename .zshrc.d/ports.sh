#!/bin/zsh

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

function killport() {
  lsof -i TCP:$1 | grep LISTEN | awk '{print $2}' | xargs kill -9
}