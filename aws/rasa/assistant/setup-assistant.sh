set -e 

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Generating kubeconfig to authenticate with EKS cluster..."
# To be able to interact with the EKS cluster we deployed earlier, we need to obtain the credentials for it. These credentials are saved in a file called kubeconfig which the AWS CLI can generate for us and kubectl can use.
# Ensure we've got a path setup for the kubeconfig file:
export KUBECONFIG=$(pwd)/kubeconfig
echo "Kubeconfig path:  $KUBECONFIG"
rm -f $KUBECONFIG
#Retrieve the credentials for the cluster using the AWS CLI:
aws eks update-kubeconfig --region $REGION --name $NAME
# Next, validate that the credentials work - we should see information about our cluster output here if everything has worked.
echo "Kubeconfig generated successfully! Printing cluster info below, if you see output here, authentication was successful."
kubectl cluster-info
kubectl get ns

# This Helm chart contains instructions for setting up the Rasa bot and Analytics components.
echo "Pulling Rasa Helm chart..."
mkdir $SCRIPT_DIR/repos
helm pull oci://europe-west3-docker.pkg.dev/rasa-releases/helm-charts/rasa --version 1.2.5 --untar --destination $SCRIPT_DIR/repos/rasa-helm

# Next, we'll ensure that other passwords and secret values that Rasa requires are set, before creating a Kubernetes Secret to securely store them in a way that we can reference later on:
echo "Creating secrets for the Rasa assistant to use..."
export AUTH_TOKEN=$(openssl rand -hex 8 | base64)
export JWT_SECRET=$(openssl rand -hex 8 | base64)
export DB_PWD=${DB_ASSISTANT_PASSWORD:-'Password is not set! Set it manually with `export DB_PWD=yourpassword`'}
export REDIS_PASSWORD=${REDIS_AUTH:-'Redis password is not set! Set it manually with `export REDIS_AUTH=yourpassword`'}
export KAFKA_CLIENT_PASSWORD=$(kubectl get secret kafka-user-passwords -n $NAMESPACE -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d ',' -f 1)
export RASA_PRO_LICENSE=${RASA_PRO_LICENSE:-'Rasa License is not set! Set it manually with `export RASA_PRO_LICENSE=yourlicense`'}
export OPENAI_API_KEY=${OPENAI_API_KEY:-'OpenAI API Key is not set! Set it manually with `export OPENAI_API_KEY=yourkey`'}

echo "Secret values retrieved. If any of the values below are not set, be sure to set them manually and re-run this script."
echo "AUTH_TOKEN: $AUTH_TOKEN"
echo "JWT_SECRET: $JWT_SECRET"
echo "DB_PWD: $DB_PWD"
echo "REDIS_PASSWORD: $REDIS_AUTH"
echo "KAFKA_CLIENT_PASSWORD: $KAFKA_CLIENT_PASSWORD"
echo "RASA_PRO_LICENSE: $RASA_PRO_LICENSE"
echo "OPENAI_API_KEY: $OPENAI_API_KEY"

echo "Creating a Kubernetes secret for these values..."
kubectl --namespace $NAMESPACE \
create secret generic rasa-secrets \
--from-literal=rasaProLicense="$(echo $RASA_PRO_LICENSE )" \
--from-literal=authToken="$(echo $AUTH_TOKEN )" \
--from-literal=jwtSecret="$(echo $JWT_SECRET)" \
--from-literal=kafkaSslPassword="$(echo $KAFKA_CLIENT_PASSWORD)" \
--from-literal=redisPassword="$(echo $REDIS_PASSWORD)" \
--from-literal=dbPassword="$(echo $DB_PWD)" \
--from-literal=openaiApiKey="$(echo $OPENAI_API_KEY)"