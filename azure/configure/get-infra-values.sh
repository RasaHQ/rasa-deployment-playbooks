echo "Fetching some infrastructure values..."

# Authenticate with Kubernetes Cluster
echo "Generating kubeconfig to authenticate with Azure Kubernetes cluster..."
# To be able to interact with the Kubernetes cluster we deployed earlier, we need to obtain the credentials for it.
# These credentials are saved in a file called kubeconfig which the cloud provider CLI tool can generate for us and kubectl can use.
# Ensure we've got a path setup for the kubeconfig file:
export KUBECONFIG=$(pwd)/kubeconfig
echo "Kubeconfig path:  $KUBECONFIG"
rm -f $KUBECONFIG
# Retrieve the credentials for the cluster:
az aks get-credentials --resource-group "$NAME" --name "$NAME"

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

export DB_ROOT_UN=postgres
export DB_ROOT_PW=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw pg_main_pw)
export DB_PORT=5432
export DB_HOST=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw db_host)

export REDIS_HOST=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw redis_host)
export REDIS_AUTH=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw redis_pw)

export SERVICE_ACCOUNT_DNS=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw client_id_dns)
export SERVICE_ACCOUNT_STUDIO=$($TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output -raw client_id_studio)

echo "Infrastructure values fetched successfully:"
echo "DB_ROOT_UN=$DB_ROOT_UN"
echo "DB_ROOT_PW=$DB_ROOT_PW"
echo "DB_PORT=$DB_PORT"
echo "DB_HOST=$DB_HOST"
echo "REDIS_HOST=$REDIS_HOST"
echo "REDIS_AUTH=$REDIS_AUTH"
echo "SERVICE_ACCOUNT_DNS=$SERVICE_ACCOUNT_DNS"
echo "SERVICE_ACCOUNT_STUDIO=$SERVICE_ACCOUNT_STUDIO"
