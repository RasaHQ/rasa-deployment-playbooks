echo "Fetching some infrastructure values..."

# Authenticate with AWS Cluster
echo "Generating kubeconfig to authenticate with AWS EKS cluster..."
# To be able to interact with the EKS cluster we deployed earlier, we need to obtain the credentials for it.
# These credentials are saved in a file called kubeconfig which the AWS CLI can generate for us and kubectl can use.
# Ensure we've got a path setup for the kubeconfig file:
export KUBECONFIG=$(pwd)/kubeconfig
echo "Kubeconfig path:  $KUBECONFIG"
rm -f $KUBECONFIG
# Retrieve the credentials for the cluster using the AWS CLI:
aws eks update-kubeconfig --region $REGION --name $NAME

# Get the directory where this script is located
# It also works when sourced from zsh
if [ -n "${BASH_SOURCE:-}" ]; then
  SCRIPT_SOURCE="${BASH_SOURCE[0]}"
elif [ -n "${ZSH_VERSION:-}" ]; then
  SCRIPT_SOURCE="${(%):-%N}"
else
  SCRIPT_SOURCE="$0"
fi
SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)"
TARGET_DIR_ABSOLUTE="$SCRIPT_DIR/../deploy/_tf"

export DB_SECRET_ID=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw secret_id_db)

aws secretsmanager get-secret-value --secret-id $DB_SECRET_ID | jq -r '.SecretString' > secret_db.json

export DB_ROOT_UN=$(jq -r '.username' secret_db.json)
export DB_ROOT_PW=$(jq -r '.password' secret_db.json)
export DB_PORT=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw db_port)
export DB_HOST=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw db_host)
export DB_HOST="${DB_HOST%:$DB_PORT}"

export REDIS_HOST=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw elasticache_primary_endpoint)
export REDIS_CLUSTER_NAME=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw elasticache_cluster_name)

export SERVICE_ACCOUNT_DNS=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw service_account_dns)
export SERVICE_ACCOUNT_ASSISTANT=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw service_account_assistant)
export SERVICE_ACCOUNT_STUDIO=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw service_account_studio)

echo "Infrastructure values fetched successfully:"
echo "DB_SECRET_ID=$DB_SECRET_ID"
echo "DB_ROOT_UN=$DB_ROOT_UN"
echo "DB_ROOT_PW=$DB_ROOT_PW"
echo "DB_PORT=$DB_PORT"
echo "DB_HOST=$DB_HOST"
echo "REDIS_HOST=$REDIS_HOST"
echo "REDIS_CLUSTER_NAME=$REDIS_CLUSTER_NAME"
echo "SERVICE_ACCOUNT_DNS=$SERVICE_ACCOUNT_DNS"
echo "SERVICE_ACCOUNT_ASSISTANT=$SERVICE_ACCOUNT_ASSISTANT"
echo "SERVICE_ACCOUNT_STUDIO=$SERVICE_ACCOUNT_STUDIO"
