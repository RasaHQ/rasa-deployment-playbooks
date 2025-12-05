set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"

envsubst < $SCRIPT_DIR/db-init.template.yaml > $SCRIPT_DIR/db-init.yaml

print_info "Initialising the database..."

kubectl delete pod db-init --ignore-not-found=true

kubectl apply -f $SCRIPT_DIR/db-init.yaml

# Wait for pod to be either ready or completed
for i in {1..30}; do
  phase=$(kubectl get pod db-init -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")

  if [ "$phase" = "Running" ] || [ "$phase" = "Succeeded" ] || [ "$phase" = "Failed" ]; then
    break
  fi

  if [ $i -eq 30 ]; then
    print_info "Timeout waiting for pod to start"
    exit 1
  fi

  sleep 1
done

kubectl logs -f pod/db-init --ignore-errors=true

# Check if pod succeeded or failed
phase=$(kubectl get pod db-init -o jsonpath='{.status.phase}' 2>/dev/null)

if [ "$phase" = "Failed" ]; then
    print_error "Database initialization pod failed!"
    exit 1
fi
