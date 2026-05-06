#!/usr/bin/env bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../../utils/common.sh"

# Validate non-secret config upfront. SERVICE_ACCOUNT_DNS / SERVICE_ACCOUNT_STUDIO are
# intentionally NOT in this list — values.template.yaml only references SERVICE_ACCOUNT_ASSISTANT.
# Secrets (RASA_PRO_LICENSE, OPENAI_API_KEY) are checked separately below — validate_variables
# echoes values, which would defeat the secret-masking elsewhere.
validate_variables NAME NAMESPACE AWS_REGION DB_HOST DB_ASSISTANT_DATABASE DB_ASSISTANT_USERNAME REDIS_HOST REDIS_USER REDIS_CLUSTER_NAME MODEL_BUCKET SERVICE_ACCOUNT_ASSISTANT

# Presence-only check for secrets (no value printing). Fail fast with a clear message
# instead of silently storing the placeholder error string in rasa-secrets.
for v in RASA_PRO_LICENSE OPENAI_API_KEY; do
  if [ -z "${!v}" ]; then
    print_error "$v is not set! Export it in your shell before running this script."
    exit 1
  fi
done

print_info "Generating kubeconfig to authenticate with EKS cluster..."
# To be able to interact with the EKS cluster we deployed earlier, we need to obtain the credentials for it. These credentials are saved in a file called kubeconfig which the AWS CLI can generate for us and kubectl can use.
# Ensure we've got a path setup for the kubeconfig file:
export KUBECONFIG=$(pwd)/kubeconfig
print_info "Kubeconfig path:  $KUBECONFIG"
rm -f $KUBECONFIG
aws eks update-kubeconfig --region $REGION --name $NAME
# Next, validate that the credentials work - we should see information about our cluster output here if everything has worked.
print_info "Kubeconfig generated successfully! Printing cluster info below, if you see output here, authentication was successful."
kubectl cluster-info
kubectl get ns

# This Helm chart contains instructions for setting up the Rasa bot and Analytics components.
print_info "Pulling Rasa Helm chart..."
mkdir -p "$SCRIPT_DIR/repos"
# Make `helm pull --untar` idempotent — remove the prior chart dir before pulling.
rm -rf "$SCRIPT_DIR/repos/rasa-helm"
helm pull oci://europe-west3-docker.pkg.dev/rasa-releases/helm-charts/rasa --version 1.3.2 --untar --destination "$SCRIPT_DIR/repos/rasa-helm"

# Next, we'll ensure that other passwords and secret values that Rasa requires are set, before creating a Kubernetes Secret to securely store them in a way that we can reference later on:
print_info "Creating secrets for the Rasa assistant to use..."
export AUTH_TOKEN=$(openssl rand -hex 8 | base64)
export JWT_SECRET=$(openssl rand -hex 8 | base64)
export KAFKA_CLIENT_PASSWORD=$(kubectl get secret kafka-user-passwords -n $NAMESPACE -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d ',' -f 1)

print_info "Secret values retrieved. Presence-only output below — raw values not printed so tee'd logs stay clean."
print_info "AUTH_TOKEN:            $([ -n "$AUTH_TOKEN" ] && echo '<set>' || echo '<not set>')"
print_info "JWT_SECRET:            $([ -n "$JWT_SECRET" ] && echo '<set>' || echo '<not set>')"
print_info "KAFKA_CLIENT_PASSWORD: $([ -n "$KAFKA_CLIENT_PASSWORD" ] && echo '<set>' || echo '<not set>')"
print_info "RASA_PRO_LICENSE:      $([ -n "$RASA_PRO_LICENSE" ] && echo '<set>' || echo '<not set>')"
print_info "OPENAI_API_KEY:        $([ -n "$OPENAI_API_KEY" ] && echo '<set>' || echo '<not set>')"

print_info "Creating a Kubernetes secret for these values..."
# Idempotent secret create — succeeds on rerun by replacing the existing Secret.
kubectl --namespace "$NAMESPACE" \
create secret generic rasa-secrets \
--from-literal=rasaProLicense="$(echo $RASA_PRO_LICENSE )" \
--from-literal=authToken="$(echo $AUTH_TOKEN )" \
--from-literal=jwtSecret="$(echo $JWT_SECRET)" \
--from-literal=kafkaSslPassword="$(echo $KAFKA_CLIENT_PASSWORD)" \
--from-literal=openaiApiKey="$(echo $OPENAI_API_KEY)" \
--dry-run=client -o yaml | kubectl apply -f -

print_info "Installing the Rasa Helm chart..."
# `envsubst` is given an explicit allowlist of template-time vars only.
# `${KAFKA_USER}` / `${KAFKA_PASSWORD}` are intentionally NOT in the list — they stay
# as literals so Rasa substitutes them at pod startup from the container env
# (additionalEnv → rasa-secrets).
# Process substitution `<(...)` keeps the rendered yaml in a /dev/fd/N pipe — never
# written to disk, so there's no rendered values file to clean up or accidentally share.
helm upgrade --install rasa "$SCRIPT_DIR/repos/rasa-helm/rasa" \
  --namespace "$NAMESPACE" \
  --values <(envsubst '${NAME} ${NAMESPACE} ${AWS_REGION} ${DB_HOST} ${DB_ASSISTANT_DATABASE} ${DB_ASSISTANT_USERNAME} ${REDIS_HOST} ${REDIS_USER} ${REDIS_CLUSTER_NAME} ${MODEL_BUCKET} ${SERVICE_ACCOUNT_ASSISTANT}' < "$SCRIPT_DIR/values.template.yaml")
