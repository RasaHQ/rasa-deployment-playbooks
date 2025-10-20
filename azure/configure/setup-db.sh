set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"

envsubst < $SCRIPT_DIR/db-init.template.yaml > $SCRIPT_DIR/db-init.yaml

print_info "Initialising the database..."

kubectl delete pod db-init --ignore-not-found=true

kubectl apply -f $SCRIPT_DIR/db-init.yaml

while ! kubectl get pod db-init &>/dev/null; do
  sleep 1
done

kubectl logs -f pod/db-init --ignore-errors=true
