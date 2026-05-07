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

# Read the RDS root credentials in-memory and unset the JSON afterward.
# Avoids writing secret_db.json to the calling user's CWD (world-readable, easy to leak).
# Avoids installing an EXIT trap from this sourced script — that would clobber the caller's trap.
DB_SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ID" --query SecretString --output text)
if [ -z "$DB_SECRET_JSON" ] || [ "$DB_SECRET_JSON" = "None" ]; then
  echo "ERROR: failed to fetch RDS secret from $DB_SECRET_ID" >&2
  return 1 2>/dev/null || exit 1
fi
export DB_ROOT_UN=$(jq -r '.username' <<<"$DB_SECRET_JSON")
export DB_ROOT_PW=$(jq -r '.password' <<<"$DB_SECRET_JSON")
unset DB_SECRET_JSON
# Post-extraction guard. `export VAR=$(jq …)` masks jq's exit code, so without this
# malformed JSON would silently produce broken downstream behaviour.
if [ -z "$DB_ROOT_UN" ] || [ "$DB_ROOT_UN" = "null" ] || [ -z "$DB_ROOT_PW" ] || [ "$DB_ROOT_PW" = "null" ]; then
  echo "ERROR: malformed RDS secret JSON — DB_ROOT_UN/DB_ROOT_PW could not be extracted" >&2
  return 1 2>/dev/null || exit 1
fi
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
# Print presence-only for the password so tee'd command logs don't capture the raw value.
echo "DB_ROOT_PW=$([ -n "$DB_ROOT_PW" ] && echo '<set>' || echo '<not set>')"
echo "DB_PORT=$DB_PORT"
echo "DB_HOST=$DB_HOST"
echo "REDIS_HOST=$REDIS_HOST"
echo "REDIS_CLUSTER_NAME=$REDIS_CLUSTER_NAME"
echo "SERVICE_ACCOUNT_DNS=$SERVICE_ACCOUNT_DNS"
echo "SERVICE_ACCOUNT_ASSISTANT=$SERVICE_ACCOUNT_ASSISTANT"
echo "SERVICE_ACCOUNT_STUDIO=$SERVICE_ACCOUNT_STUDIO"
