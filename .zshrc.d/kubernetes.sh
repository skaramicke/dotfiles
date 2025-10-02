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

# Add to your ~/.zshrc (or source it in your shell)
vllmlog() {
  kubectl logs -f "$@" | awk '
    function extract_prompt(line,   p,start,rest,i,n,prev,c,end,txt) {
      p = index(line, "prompt: '\''");
      if (!p) return "";
      start = p + 9;                        # length("prompt: '\''") == 9
      rest = substr(line, start);
      n = length(rest);
      end = 0;
      prev = "";
      for (i = 1; i <= n; i++) {            # find next unescaped single quote
        c = substr(rest, i, 1);
        if (c == "'\''" && prev != "\\") {  end = i - 1; break }
        prev = c;
      }
      if (end == 0) end = n;
      txt = substr(rest, 1, end);
      gsub(/\\n/, "\n", txt);               # turn "\n" into real newlines
      return txt;
    }
    {
      if ($0 ~ /Received request/) {
        txt = extract_prompt($0);
        if (txt != "") print txt "\n";
      } else if ($0 ~ /(ERROR|Error|Exception|Traceback|CRITICAL|WARNING)/) {
        print $0;
      }
      # else: ignore
    }'
}

# function
status() {
  if [[ $# -eq 0 ]]; then
    echo "usage: status [kubectl flags] <elxcluster-name>"
    return 1
  fi
  local -a cmd
  cmd=(kubectl get elxcluster "$@" -o go-template='{{.metadata.name}}{{"\n"}}  Status: {{if .status.ready}}Ready{{else}}Not ready{{end}}{{"\n"}}  Reason: {{if .status.reason}}{{.status.reason}}{{else}}All is OK{{end}}{{"\n"}}')
  local cmd_str
  cmd_str=$(printf '%q ' "${cmd[@]}")
  watch "${cmd_str% }"
}

# ensure kubectl zsh completion is loaded
if ! type _kubectl &>/dev/null; then
  autoload -Uz compinit && compinit
  [[ -n "$(command -v kubectl)" ]] && source <(kubectl completion zsh)
fi

# completion wrapper: pretend the user typed "kubectl get elxcluster ..."
_status() {
  local -a savewords; local saveCURRENT
  savewords=("${words[@]}"); saveCURRENT=$CURRENT
  words=(kubectl get elxcluster "${words[@]:1}")
  CURRENT=$(( CURRENT + 2 ))
  _kubectl
  words=("${savewords[@]}"); CURRENT=$saveCURRENT
}
compdef _status status
