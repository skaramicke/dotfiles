#!/bin/zsh

yq e '.contexts[].name' ~/.kube/config | while read -r cluster; do
	alias $cluster="kubectl --context $cluster"
done

function status() {
	if [[ -z $1 || -z $2 ]]; then
		echo "Usage: status <resource> <name>"
		return 1
	fi

	kubectl get $1 -o yaml | yq ".items[] | select(.metadata.name == \"$2\") | .status"
}

function statusw() {
	if [[ -z $1 || -z $2 ]]; then
		echo "Usage: status <resource> <name>"
		return 1
	fi

	watch "kubectl get $1 -o yaml | yq '.items[] | select(.metadata.name == \"$2\") | .status'"

}
