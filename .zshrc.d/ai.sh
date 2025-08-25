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
  payload=$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}]}' \
    "$model" "$prompt")

  # ensure port-forward tunnel is up
  _ai_start_port_forward
  local endpoint="http://localhost:$AI_PORT/v1/chat/completions"
  # call the API silently, extract only the generated text
  curl -s "$endpoint" \
    -H "Content-Type: application/json" \
    -d "$payload" \
  | jq -r '.choices[0].message.content'
}

# ~/.zshrc.d/ai.sh

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