set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"
source "$SCRIPT_DIR/../utils/common.sh"

auth_to_k8s

print_info "Deleting Studio Helm chart if it already exists..."
rm -rf $SCRIPT_DIR/repos

print_info "Pulling Studio Helm chart..."
mkdir $SCRIPT_DIR/repos
helm pull oci://europe-west3-docker.pkg.dev/rasa-releases/helm-charts/studio --version 2.1.6 --untar --destination $SCRIPT_DIR/repos/studio-helm

print_info "Getting storage account key..."
SAKEYS_OUTPUT_OUTPUT=$(az storage account keys list \
  --resource-group $NAME \
  --account-name $NAME)

# Next, we'll ensure that other passwords and secret values that Rasa Studio requires are set, before creating a Kubernetes Secret to securely store them in a way that we can reference later on:
print_info "Creating secrets for the Rasa Studio to use..."
export KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -hex 8 | base64)
export KEYCLOAK_API_PASSWORD=$(openssl rand -hex 8 | base64)
export KAFKA_CLIENT_PASSWORD=$(kubectl get secret kafka -n $NAMESPACE -o jsonpath='{.data.password}' | base64 -d | cut -d ',' -f 1)
export DB_STUDIO_PASSWORD=${DB_STUDIO_PASSWORD}
export STORAGE_ACCOUNT_KEY=$(echo $SAKEYS_OUTPUT_OUTPUT | jq -r '.[0].value')

# Validate all required secret variables
validate_variables \
    "KEYCLOAK_ADMIN_PASSWORD" \
    "KEYCLOAK_API_PASSWORD" \
    "KAFKA_CLIENT_PASSWORD" \
    "DB_STUDIO_PASSWORD" \
    "RASA_PRO_LICENSE" \
    "OPENAI_API_KEY"

print_info "Deleting a secret if it already exists..."
kubectl delete secret studio-secrets -n $NAMESPACE || true

print_info "Creating a Kubernetes secret for these values..."
kubectl --namespace $NAMESPACE \
create secret generic studio-secrets \
--from-literal=KEYCLOAK_ADMIN_PASSWORD="$(echo $KEYCLOAK_ADMIN_PASSWORD)" \
--from-literal=KEYCLOAK_API_PASSWORD="$(echo $KEYCLOAK_API_PASSWORD)" \
--from-literal=KAFKA_SASL_PASSWORD="$(echo $KAFKA_CLIENT_PASSWORD)" \
--from-literal=DATABASE_PASSWORD="$(echo $DB_STUDIO_PASSWORD)" \
--from-literal=DATABASE_URL="postgresql://${DB_STUDIO_USERNAME}:${DB_STUDIO_PASSWORD}@${DB_HOST}:5432/${DB_STUDIO_DATABASE}" \
--from-literal=storageAccountKey="$(echo STORAGE_ACCOUNT_KEY)" \
--from-literal=RASA_PRO_LICENSE_SECRET_KEY="$(echo $RASA_PRO_LICENSE)" \
--from-literal=OPENAI_API_KEY_SECRET_KEY="$(echo $OPENAI_API_KEY)"

print_info ""
print_info ""
print_info "KEYCLOAK CREDENTIALS"
print_info "===================="
print_info "You will need to set the following credentials to set up Rasa Studio once it is deployed:"
print_info "Username: kcadmin"
print_info "Password: $KEYCLOAK_ADMIN_PASSWORD"
print_info "Keep a record of these credentials now."
print_info "===================="

