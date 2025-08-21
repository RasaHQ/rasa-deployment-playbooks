set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"

envsubst < $SCRIPT_DIR/db-init.template.yaml > $SCRIPT_DIR/db-init.yaml

print_info "Initialising the database..."
kubectl apply -f $SCRIPT_DIR/db-init.yaml