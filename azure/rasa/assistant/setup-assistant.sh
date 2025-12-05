set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../../utils/common.sh"
source "$SCRIPT_DIR/../../utils/common.sh"

auth_to_k8s

print_info "Deleting Rasa Helm chart if it already exists..."
rm -rf $SCRIPT_DIR/repos

# This Helm chart contains instructions for setting up theRasa bot and Analytics components.
print_info "Pulling Rasa Helm chart..."
mkdir $SCRIPT_DIR/repos
helm pull oci://europe-west3-docker.pkg.dev/rasa-releases/helm-charts/rasa --version 1.2.5 --untar --destination $SCRIPT_DIR/repos/rasa-helm

print_info "Getting storage account key..."
SAKEYS_OUTPUT_OUTPUT=$(az storage account keys list \
  --resource-group $NAME \
  --account-name $NAME)

# Next, we'll ensure that other passwords and secret values that Rasa requires are set, before creating a Kubernetes Secret to securely store them in a way that we can reference later on:
print_info "Creating secrets for the Rasa assistant to use..."
export AUTH_TOKEN=$(openssl rand -hex 8 | base64)
export JWT_SECRET=$(openssl rand -hex 8 | base64)
export KAFKA_CLIENT_PASSWORD=$(kubectl get secret kafka -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d | cut -d ',' -f 1)
export STORAGE_ACCOUNT_KEY=$(echo $SAKEYS_OUTPUT_OUTPUT | jq -r '.[0].value')

print_info "Secret values retrieved. Validating that all required values are set..."

# Validate all required secret variables
validate_variables \
    "AUTH_TOKEN" \
    "JWT_SECRET" \
    "REDIS_AUTH" \
    "KAFKA_CLIENT_PASSWORD" \
    "DB_ASSISTANT_PASSWORD" \
    "STORAGE_ACCOUNT_KEY" \
    "RASA_PRO_LICENSE" \
    "OPENAI_API_KEY"

print_info "Deleting a secret if it already exists..."
kubectl delete secret rasa-secrets -n $NAMESPACE || true

print_info "Creating a Kubernetes secret for these values..."
kubectl --namespace $NAMESPACE \
create secret generic rasa-secrets \
--from-literal=authToken="$(echo $AUTH_TOKEN )" \
--from-literal=jwtSecret="$(echo $JWT_SECRET)" \
--from-literal=redisPassword="$(echo $REDIS_AUTH)" \
--from-literal=kafkaSslPassword="$(echo $KAFKA_CLIENT_PASSWORD)" \
--from-literal=dbPassword="$(echo $DB_ASSISTANT_PASSWORD)" \
--from-literal=storageAccountKey="$(echo $STORAGE_ACCOUNT_KEY)" \
--from-literal=rasaProLicense="$(echo $RASA_PRO_LICENSE )" \
--from-literal=openaiApiKey="$(echo $OPENAI_API_KEY)"

