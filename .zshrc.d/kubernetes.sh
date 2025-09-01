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
