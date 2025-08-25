# ~/.zshrc.d/ai.sh

# Requires: jq

# Helper: fetch (and cache) the first available model ID from vLLM
# Cache result in AI_MODEL for AI_MODEL_TTL seconds (default 3600)
AI_MODEL_TTL=${AI_MODEL_TTL:-3600}
AI_MODEL_FETCH_TS=${AI_MODEL_FETCH_TS:-0}
function _ai_get_model() {
  local now=$(date +%s)
  if [[ -n "$AI_MODEL" && $((now - AI_MODEL_FETCH_TS)) -lt $AI_MODEL_TTL ]]; then
    printf '%s' "$AI_MODEL"
  else
    local model
    model=$(curl -s http://localhost:8000/v1/models \
      -H "Content-Type: application/json" \
    | jq -r '.data[0].id')
    AI_MODEL=$model
    AI_MODEL_FETCH_TS=$now
    printf '%s' "$model"
  fi
}

# Helper: manage kubectl port-forward for vLLM
function _ai_find_free_port() {
  for port in {8000..9000}; do
    if ! lsof -iTCP:$port -sTCP:LISTEN -t &>/dev/null; then
      echo $port
      return
    fi
  done
  echo "Error: no free port" >&2
  return 1
}

function _ai_start_port_forward() {
  if [[ -z "$AI_PORT_FORWARD_PID" ]] || ! kill -0 "$AI_PORT_FORWARD_PID" 2>/dev/null; then
    AI_PORT=$(_ai_find_free_port)
    kubectl --context elastx-agent1-admin@elastx-agent1 port-forward deployments/vllm "$AI_PORT":8000 >/dev/null 2>&1 &
    AI_PORT_FORWARD_PID=$!
    # wait for port to be listening
    for i in {1..10}; do
      nc -z localhost "$AI_PORT" && break
      sleep 0.1
    done
  fi
}

# ensure port-forward is killed on shell exit
trap '[[ -n "$AI_PORT_FORWARD_PID" ]] && kill "$AI_PORT_FORWARD_PID"' EXIT

function ai() {
  # join all arguments into a single prompt string
  local prompt="${*}"
  # replace placeholder {} with stdin content if present
  if [[ "$prompt" == *"{}"* ]]; then
    local stdin_data
    stdin_data=$(cat -)
    prompt=${prompt//\{\}/$stdin_data}
  fi
  # determine model dynamically
  local model=$(_ai_get_model)
  # build JSON payload safely with proper substitutions
  local payload

  # multiline system prompt for easier editing
  local system_prompt
  system_prompt=$(
    cat <<'EOF'
You are a helpful assistant that the user runs from their terminal.

If the user asks you to create something that goes in a single file, like a piece of code or a poem or something like that, expect that your full output will be put directly into that file. In such cases, NEVER add descriptions, backticks, or anything of the sort; just output the plain code or text directly without additions. This is VERY important.

Examples:

user: Write a python script that prints hello world
assistant: print("hello world")

Wrong:
user: Write a python script that prints hello world
assistant: ```python
print("hello world")
```

YOU SHOULD NOT ADD WRAPPERS AROUND CODE WHEN THE USER MIGHT WANT TO RUN IT DIRECTLY.

EOF
  )

  # build JSON payload safely
  payload=$(jq -n \
    --arg model "$model" \
    --arg system "$system_prompt" \
    --arg prompt "$prompt" \
    '{model:$model, messages:[{role:"system", content:$system}, {role:"user", content:$prompt}]}')

  # ensure port-forward tunnel is up
  _ai_start_port_forward
  local endpoint="http://localhost:$AI_PORT/v1/chat/completions"
  # call the API silently, extract only the generated text
  curl -s "$endpoint" \
    -H "Content-Type: application/json" \
    -d "$payload" \
  | jq -r '.choices[0].message.content'
}

# Requires: jq
function ais() {
  local prompt="$*"
  # replace placeholder {} with stdin content if present
  if [[ "$prompt" == *"{}"* ]]; then
    local stdin_data
    stdin_data=$(cat -)
    prompt=${prompt//\{\}/$stdin_data}
  fi
  # determine model dynamically
  local model=$(_ai_get_model)
  local payload
  payload=$(printf '{"model":"%s","stream":true,"messages":[{"role":"user","content":"%s"}]}' \
    "$model" "$prompt")

  echo "$payload"

  # ensure port-forward tunnel is up
  _ai_start_port_forward
  local endpoint="http://localhost:$AI_PORT/v1/chat/completions"
  curl -s -N "$endpoint" \
    -H "Content-Type: application/json" \
    -d "$payload" |
  while IFS= read -r line; do
    # only process lines that start with “data: ”
    if [[ $line == data:* ]]; then
      # strip the “data: ” prefix
      data_line=${line#data: }
      # skip end-of-stream sentinel
      [[ "$data_line" == "[DONE]" ]] && continue
      # output the delta.content raw (preserving any newlines)
      jq -rj '.choices[0].delta.content // empty' <<< "$data_line"
    fi
  done
  echo
}

## Function that strips triple backtick code blocks from text
# Usage:
#   strip_code_blocks "text with ```fences```"
#   some_command | strip_code_blocks
function strip_code_blocks() {
  local data
  if [[ -t 0 ]]; then data="$*"; else data="$(cat)"; fi
  perl -0777 -e '
    my $s = do { local $/; <> };
    $s =~ s/\r\n/\n/g;              # normalize newlines
    my $out;
    if ($s =~ /```[ \t]*[A-Za-z0-9._+-]*\s*\R(.*?)\R```/s) { $out = $1 }   # ```lang\n...\n```
    elsif ($s =~ /```\s*\R(.*?)\R```/s)                   { $out = $1 }   # ```\n...\n```
    else                                                  { $out = $s }   # no fences → whole text
    $out =~ s/\A\s+|\s+\z//g;       # trim
    print $out;
  ' <<<"$data"
}

# Helper: run Python code using the AI venv interpreter if available, without touching parent shell env
# This avoids activating/deactivating environments in the current shell.
_aip_run_py() {
  local code="$1"
  local ai_venv="$HOME/.config/ai/venv"
  if [[ -x "$ai_venv/bin/python3" ]]; then
    "$ai_venv/bin/python3" -c "$code"
  elif [[ -x "$ai_venv/bin/python" ]]; then
    "$ai_venv/bin/python" -c "$code"
  else
    python3 -c "$code"
  fi
}


# Function that asks for a python script to solve what ever the user prompts for as arguments, then runs that using python
function aip() {
  local prompt="$*"
  # replace placeholder {} with stdin content if present
  if [[ "$prompt" == *"{}"* ]]; then
    local stdin_data
    stdin_data=$(cat -)
    prompt=${prompt//\{\}/$stdin_data}
  fi

  echo "Working on it..."

  # Get the result using the `ai` function above
  local result
  result=$(strip_code_blocks "$(ai "Write a python script that without any sort of credentials or API keys solves this: '$prompt'")")

  # Run the result using python
  local output
  output=$(_aip_run_py "$result")
  local exit_code=$?

  # If the exit code is non-zero, get the AI to reiterate
  if [[ $exit_code -ne 0 ]]; then
    echo "Failed, trying again..."
    local result2
    result2=$(strip_code_blocks "$(ai "I asked you to write a python script that solves this: '$prompt'. You responded with the following code: '$result' which failed and gave this result: '$output'. Try again, write a python script, without any extra text, that solves this: '$prompt'")")
    local output2
    output2=$(_aip_run_py "$result2")
    local status2=$?
    if [[ $status2 -ne 0 ]]; then
      echo "Failed twice, giving up"
      echo "First attempt:"
      echo "$result"
      echo "Result:"
      echo "$output"
      echo "Second attempt:"
      echo "$result2"
      echo "Result:"
      echo "$output2"
    else
      echo "$output2"
    fi
  else
    echo "$output"
  fi
}
