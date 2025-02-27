# When entering a directory, load .zshrc.local if it exists
function chpwd() {
	if [[ -f .zshrc.local ]]; then
		source .zshrc.local
	fi
	if [[ -f .nvmrc ]]; then
		nvm use
	fi
}
