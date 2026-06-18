#!/usr/bin/env bash
set -euo pipefail

# Post-deploy verification for A2A multi-replica Rasa on AWS.
# Run after setup-assistant.sh, setup-ingress.sh, and model upload to S3.
#
# Usage:
#   source aws/setup/environment-variables.sh
#   export KUBECONFIG=$(pwd)/kubeconfig   # optional, for cluster checks
#   ./aws/rasa/assistant/verify-a2a-deployment.sh
#
# If curl fails DNS while dig works (common on macOS), the script resolves via dig
# and passes --resolve to curl. Set VERIFY_A2A_SKIP_DNS_RESOLVE=1 to disable.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../utils/common.sh"

validate_variables DOMAIN NAMESPACE NAME

ASSISTANT_URL="${ASSISTANT_URL:-https://assistant.${DOMAIN}}"
ASSISTANT_HOST="assistant.${DOMAIN}"
COOKIE_JAR="$(mktemp)"
TMP_RESPONSE="$(mktemp)"
CURL_RESOLVE_ARGS=()
trap 'rm -f "$COOKIE_JAR" "$TMP_RESPONSE"' EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    print_error "Required command not found: $1"
    exit 1
  }
}

need_cmd curl
need_cmd jq
need_cmd uuidgen

# macOS often resolves via `dig` before `curl`/`getaddrinfo` sees new records.
# Pre-resolve with dig and pass --resolve to curl so verification matches public DNS.
setup_curl_resolve() {
  local host="$1"
  local ips=""

  if [[ "${VERIFY_A2A_SKIP_DNS_RESOLVE:-}" == "1" ]]; then
    return 0
  fi

  need_cmd dig
  ips="$(dig +time=3 +tries=2 +short A "$host" 2>/dev/null | grep -E '^[0-9]+\.' || true)"
  if [[ -z "$ips" ]]; then
    return 1
  fi

  CURL_RESOLVE_ARGS=()
  while IFS= read -r ip; do
    [[ -n "$ip" ]] && CURL_RESOLVE_ARGS+=(--resolve "${host}:443:${ip}")
  done <<< "$ips"
  return 0
}

a2a_curl() {
  # Prefer IPv4; Route53 alias AAAA (NAT64) can confuse curl on some networks.
  curl -sS -4 "${CURL_RESOLVE_ARGS[@]}" "$@"
}
json_get() {
  local filter="$1"
  jq -r "$filter" "$TMP_RESPONSE"
}

a2a_post() {
  local payload="$1"
  a2a_curl -f \
    -c "$COOKIE_JAR" -b "$COOKIE_JAR" \
    -H "Content-Type: application/json" \
    -X POST "$ASSISTANT_URL/" \
    -d "$payload" \
    -o "$TMP_RESPONSE"
}

print_info "Assistant URL: $ASSISTANT_URL"

print_info "Checking DNS for $ASSISTANT_HOST..."
if setup_curl_resolve "$ASSISTANT_HOST"; then
  if [[ ${#CURL_RESOLVE_ARGS[@]} -gt 0 ]]; then
    print_info "DNS OK via dig (${#CURL_RESOLVE_ARGS[@]} A record(s)); curl will use --resolve (set VERIFY_A2A_SKIP_DNS_RESOLVE=1 to disable)."
  else
    print_info "DNS resolve helper disabled (VERIFY_A2A_SKIP_DNS_RESOLVE=1)."
  fi
else
  print_error "Could not resolve A records for $ASSISTANT_HOST (dig returned nothing)."
  print_error "Your browser may work while curl fails until macOS refreshes its DNS cache."
  print_error "Try: dig +short A $ASSISTANT_HOST"
  print_error "Then: sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder"
  exit 1
fi

# --- Cluster pre-checks (optional) -------------------------------------------

if [[ -n "${KUBECONFIG:-}" ]] && command -v kubectl >/dev/null 2>&1; then
  print_info "Checking Rasa pod readiness..."
  if kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=rasa" >/dev/null 2>&1; then
    kubectl wait -n "$NAMESPACE" \
      -l "app.kubernetes.io/name=rasa" \
      --for=condition=Ready \
      pod --timeout=300s
    RASA_REPLICAS="$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=rasa" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l | tr -d ' ')"
    print_info "Running Rasa pods: ${RASA_REPLICAS:-0}"
    if [[ "${RASA_REPLICAS:-0}" -lt 2 ]]; then
      print_error "Expected at least 2 Rasa replicas for stickiness testing; found ${RASA_REPLICAS:-0}."
      exit 1
    fi
  else
    print_info "Rasa label app.kubernetes.io/name=rasa not found; skipping pod wait."
  fi

  print_info "Checking A2A Istio resources..."
  kubectl get destinationrule -n "$NAMESPACE" -l "istio.io/rev" 2>/dev/null || \
    kubectl get destinationrule -n "$NAMESPACE" | grep -E "${NAME}-rasa-a2a-sticky|rasa-a2a-sticky" || true
  kubectl get envoyfilter -n istio-system "$NAME-a2a-context-id-extract" >/dev/null 2>&1 && \
    print_info "EnvoyFilter $NAME-a2a-context-id-extract: present" || \
    print_info "EnvoyFilter $NAME-a2a-context-id-extract: not found (apply setup-ingress.sh)"
else
  print_info "KUBECONFIG/kubectl not available — skipping cluster pre-checks."
fi

# --- 1. AgentCard -------------------------------------------------------------

print_info "Test 1: GET AgentCard"
a2a_curl -f "$ASSISTANT_URL/.well-known/agent-card.json" -o "$TMP_RESPONSE"
CARD_URL="$(json_get '.url // empty')"
CARD_NAME="$(json_get '.name // .description // empty')"
print_info "AgentCard url: ${CARD_URL:-<missing>}"
print_info "AgentCard name/description: ${CARD_NAME:-<missing>}"
if [[ -z "$CARD_URL" ]]; then
  print_error "AgentCard missing url field."
  exit 1
fi

# --- 2. message/send turn 1 (new contextId) -----------------------------------

CONTEXT_ID="ctx-verify-$(uuidgen | tr '[:upper:]' '[:lower:]')"
MSG_ID_1="msg-$(uuidgen | tr '[:upper:]' '[:lower:]')"

print_info "Test 2: message/send turn 1 (contextId=$CONTEXT_ID)"
a2a_post "$(cat <<EOF
{
  "jsonrpc": "2.0",
  "id": "verify-send-1",
  "method": "message/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "I want to add someone to my contact list"}],
      "messageId": "$MSG_ID_1",
      "contextId": "$CONTEXT_ID"
    }
  }
}
EOF
)"
TASK_ID="$(json_get '.result.id // .result.task.id // empty')"
STATE_1="$(json_get '.result.status.state // .result.state // empty')"
print_info "Turn 1 task id: ${TASK_ID:-<missing>}"
print_info "Turn 1 state: ${STATE_1:-<missing>}"
if [[ "$STATE_1" != "input-required" && "$STATE_1" != "completed" ]]; then
  print_error "Expected input-required or completed on turn 1; got: $STATE_1"
  cat "$TMP_RESPONSE" >&2
  exit 1
fi

if [[ ! -s "$COOKIE_JAR" ]]; then
  print_info "No a2a-context-id cookie captured yet (filter sets it on responses when contextId is routed)."
else
  print_info "a2a-context-id cookie captured after turn 1."
fi

# --- 3. message/send turn 2 (same contextId) ----------------------------------

MSG_ID_2="msg-$(uuidgen | tr '[:upper:]' '[:lower:]')"
print_info "Test 3: message/send turn 2 (same contextId)"
a2a_post "$(cat <<EOF
{
  "jsonrpc": "2.0",
  "id": "verify-send-2",
  "method": "message/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "please continue with that handle"}],
      "messageId": "$MSG_ID_2",
      "contextId": "$CONTEXT_ID"
    }
  }
}
EOF
)"
STATE_2="$(json_get '.result.status.state // .result.state // empty')"
print_info "Turn 2 state: ${STATE_2:-<missing>}"
if [[ -z "$STATE_2" ]]; then
  print_error "Turn 2 returned no task state."
  cat "$TMP_RESPONSE" >&2
  exit 1
fi

# --- 4. tasks/cancel (a2a-context-id cookie or X-A2A-Context-Id, no body contextId) ---

if [[ "$STATE_1" == "input-required" && -n "$TASK_ID" ]]; then
  print_info "Test 4: tasks/cancel (same cookie jar from turns 1-2; task_id only in body)"
  print_info "EnvoyFilter maps a2a-context-id cookie -> x-a2a-context-id for consistent hash."
  a2a_post "$(cat <<EOF
{
  "jsonrpc": "2.0",
  "id": "verify-cancel-1",
  "method": "tasks/cancel",
  "params": {"id": "$TASK_ID"}
}
EOF
)"
  CANCEL_STATE="$(json_get '.result.status.state // .result.state // empty')"
  print_info "Cancel state: ${CANCEL_STATE:-<missing>}"
  if [[ "$CANCEL_STATE" != "canceled" ]]; then
    print_error "Expected canceled after tasks/cancel; got: $CANCEL_STATE"
    cat "$TMP_RESPONSE" >&2
    exit 1
  fi
else
  print_info "Test 4: skipped tasks/cancel (turn 1 did not leave input-required or no task id)."
fi

# --- 5. Stickiness guidance ---------------------------------------------------

print_info "Test 5: contextId stickiness (manual confirmation)"
print_info "Send two requests with different contextIds, then confirm each contextId"
print_info "consistently hits the same pod in logs:"
print_info ""
print_info "  CTX_A=ctx-stick-a-\$(uuidgen | tr '[:upper:]' '[:lower:]')"
print_info "  CTX_B=ctx-stick-b-\$(uuidgen | tr '[:upper:]' '[:lower:]')"
print_info "  # POST message/send for CTX_A twice, then CTX_B twice (reuse this script's payloads)."
print_info "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=rasa --since=5m | grep -E \"\$CTX_A|\$CTX_B\""
print_info ""
print_info "Same contextId should appear in one pod's logs only; different contextIds may land on different pods."

if [[ -n "${KUBECONFIG:-}" ]] && command -v kubectl >/dev/null 2>&1; then
  SANIC_WORKERS="$(kubectl get pods -n "$NAMESPACE" -l "app.kubernetes.io/name=rasa" -o jsonpath='{.items[0].spec.containers[?(@.name=="rasa")].env[?(@.name=="SANIC_WORKERS")].value}' 2>/dev/null || true)"
  if [[ -n "$SANIC_WORKERS" && "$SANIC_WORKERS" != "1" ]]; then
    print_error "SANIC_WORKERS=$SANIC_WORKERS (expected 1 for A2A)."
    exit 1
  fi
  print_info "SANIC_WORKERS=${SANIC_WORKERS:-<not found>} (expected 1)."
fi

print_info "All automated A2A verification checks passed."
