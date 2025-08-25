# Apple Silicon Homebrew first
export PATH="/opt/homebrew/bin:$PATH"
# GOPATH (default is $HOME/go; set explicitly for clarity)
export GOPATH="$HOME/go"
# Go tools (gopls, etc.)
export PATH="$PATH:$GOPATH/bin"