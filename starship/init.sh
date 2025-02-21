
SCRIPT_LOCATION=$(dirname $0)

eval "$(starship init zsh)"

export STARSHIP_CONFIG=$SCRIPT_LOCATION/config.toml