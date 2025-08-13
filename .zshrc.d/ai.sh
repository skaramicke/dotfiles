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

function ai() {
  # join all arguments into a single prompt string
  local prompt="${*}"
  # determine model dynamically
  local model=$(_ai_get_model)
  # build JSON payload safely with proper substitutions
  local payload
  payload=$(printf '{"model":"%s","messages":[{"role":"user","content":"%s"}]}' \
    "$model" "$prompt")

  # call the API silently, extract only the generated text
  curl -s http://localhost:8000/v1/chat/completions \
    -H "Content-Type: application/json" \
    -d "$payload" \
  | jq -r '.choices[0].message.content'
}

# ~/.zshrc.d/ai.sh

# Requires: jq
function ais() {
  local prompt="$*"
  # determine model dynamically
  local model=$(_ai_get_model)
  local payload
  payload=$(printf '{"model":"%s","stream":true,"messages":[{"role":"user","content":"%s"}]}' \
    "$model" "$prompt")

  curl -s -N http://localhost:8000/v1/chat/completions \
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