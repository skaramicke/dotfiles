#!/bin/zsh
generate-sealed-secret() {
	# Configuration variables
	local required_k8s_context="gronit-cluster1"

	# Function variables
	local secret_name=""
	local namespace="default"
	local secret_data=()

	# First argument should be the secret name
	if [[ $# -gt 0 && ! $1 =~ ^-- ]]; then
		secret_name="$1"
		shift
	fi

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
		--namespace)
			namespace="$2"
			shift 2
			;;
		--namespace=*)
			namespace="${1#*=}"
			shift
			;;
		--*)
			# Extract variable name from flag (remove leading --)
			local var_name="${1#--}"

			# Handle both --flag=value and --flag value formats
			if [[ $1 == *=* ]]; then
				local op_ref="${1#*=}"
				shift
			else
				local op_ref="$2"
				shift 2
			fi

			# Keep the variable name exactly as provided
			# No conversion to snake_case or any other modification

			# Retrieve the secret from 1Password
			local secret_value=$(op read "$op_ref")

			if [[ -z $secret_value ]]; then
				echo "Error: Failed to retrieve secret for $var_name from 1Password" >&2
				return 1
			fi

			secret_data+=("--from-literal=${var_name}=${secret_value}")
			;;
		*)
			echo "Unknown argument: $1" >&2
			return 1
			;;
		esac
	done

	# Check if secret name was provided
	if [[ -z $secret_name ]]; then
		echo "Error: Secret name is required" >&2
		return 1
	fi

	# Verify that kubectl context is the required one
	if [[ $(kubectl config current-context) != "$required_k8s_context" ]]; then
		echo "Error: Kubectl context is not set to $required_k8s_context" >&2
		return 1
	fi

	# Create a temporary file for the secret
	local tmp_secret_file=$(mktemp)

	# Create Kubernetes secret and output to the temporary file
	kubectl create secret generic "$secret_name" \
		--namespace="$namespace" \
		"${secret_data[@]}" \
		--dry-run=client -o yaml >"$tmp_secret_file"

	# Seal the secret and output to stdout
	kubeseal --scope cluster-wide --format yaml <"$tmp_secret_file"

	# Clean up temporary file
	rm "$tmp_secret_file"
}
