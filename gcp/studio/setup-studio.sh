set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Generating kubeconfig to authenticate with GKE cluster..."
# To be able to interact with the GKE cluster we deployed earlier, we need to obtain the credentials for it. These credentials are saved in a file called kubeconfig which the gcloud CLI can generate for us and kubectl can use.
# Ensure we've got a path setup for the kubeconfig file:
export KUBECONFIG=$(pwd)/kubeconfig
echo "Kubeconfig path:  $KUBECONFIG"
rm -f $KUBECONFIG
#Retrieve the credentials for the cluster using the gcloud CLI:
gcloud container clusters get-credentials $NAME --region=$REGION 
# Next, validate that the credentials work - we should see information about our cluster output here if everything has worked.
echo "Kubeconfig generated successfully! Printing cluster info below, if you see output here, authentication was successful."
kubectl cluster-info
kubectl get ns

echo "Pulling Rasa Studio Helm chart..."
mkdir $SCRIPT_DIR/repos
helm pull oci://europe-west3-docker.pkg.dev/rasa-releases/helm-charts/studio --version 2.1.6 --untar --destination $SCRIPT_DIR/repos/studio-helm

# Next, we'll ensure that other passwords and secret values that Rasa Studio requires are set, before creating a Kubernetes Secret to securely store them in a way that we can reference later on:
echo "Creating secrets for the Rasa Studio to use..."
export KEYCLOAK_ADMIN_PASSWORD=$(openssl rand -hex 8 | base64)
export KEYCLOAK_API_PASSWORD=$(openssl rand -hex 8 | base64)
export REDIS_PASSWORD=${REDIS_AUTH:-$(gcloud redis instances get-auth-string $NAME --region=$REGION --format='value(authString)')}
export KAFKA_CLIENT_PASSWORD=$(kubectl get secret kafka-user-passwords -n $NAMESPACE -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d ',' -f 1)
export OPENAI_API_KEY_SECRET_KEY=${OPENAI_API_KEY:-'OpenAI API Key is not set! Set it manually with `export OPENAI_API_KEY=yourkey`'}
export DB_STUDIO_PASSWORD=${DB_STUDIO_PASSWORD:-'Password is not set! Set it manually with `export DB_STUDIO_PASSWORD=yourpassword`'}

echo "Secret values retrieved. If any of the values below are not set, be sure to set them manually and re-run this script."
echo "KEYCLOAK_ADMIN_PASSWORD: $KEYCLOAK_ADMIN_PASSWORD"
echo "KEYCLOAK_API_PASSWORD: $KEYCLOAK_API_PASSWORD"
echo "REDIS_PASSWORD: $REDIS_PASSWORD"
echo "KAFKA_CLIENT_PASSWORD: $KAFKA_CLIENT_PASSWORD"
echo "OPENAI_API_KEY_SECRET_KEY: $OPENAI_API_KEY_SECRET_KEY"
echo "DB_STUDIO_PASSWORD: $DB_STUDIO_PASSWORD"

echo "Deleting a secret if it already exists..."
kubectl delete secret studio-secrets -n $NAMESPACE

echo "Creating a Kubernetes secret for these values..."
kubectl --namespace $NAMESPACE \
create secret generic studio-secrets \
--from-literal=RASA_PRO_LICENSE_SECRET_KEY="$(echo $RASA_PRO_LICENSE)" \
--from-literal=OPENAI_API_KEY_SECRET_KEY="$(echo $OPENAI_API_KEY_SECRET_KEY)" \
--from-literal=KAFKA_SASL_PASSWORD="$(echo $KAFKA_CLIENT_PASSWORD)" \
--from-literal=KEYCLOAK_ADMIN_PASSWORD="$(echo $KEYCLOAK_ADMIN_PASSWORD)" \
--from-literal=KEYCLOAK_API_PASSWORD="$(echo $KEYCLOAK_API_PASSWORD)" \
--from-literal=DATABASE_PASSWORD="$(echo $DB_STUDIO_PASSWORD)" \
--from-literal=DATABASE_URL="postgresql://${DB_STUDIO_USERNAME}:${DB_STUDIO_PASSWORD}@${DB_HOST}:5432/${DB_STUDIO_DATABASE}"


echo "\n\nKEYCLOAK CREDENTIALS"
echo "===================="
echo "You will need to set the following credentials to set up Rasa Studio once it is deployed:"
echo "Username: kcadmin"
echo "Password: $KEYCLOAK_ADMIN_PASSWORD"
echo "Keep a record of these credentials now."
echo "===================="