set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

envsubst < $SCRIPT_DIR/db-init.template.yaml > $SCRIPT_DIR/db-init.yaml

echo "Initialising the database..."
kubectl apply -f $SCRIPT_DIR/db-init.yaml