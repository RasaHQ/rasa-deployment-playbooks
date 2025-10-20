set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"
source "$SCRIPT_DIR/../utils/common.sh"

auth_to_k8s

print_info "Starting cleanup of Azure infrastructure..."

print_info "Uninstalling Istio..."

export ISTIO_DIR=$(ls | grep -v istio-operator.yaml | grep istio- | sort --version-sort | tail -1)
print_info "Istio dir:  $ISTIO_DIR"
export ISTIO="$ISTIO_DIR/bin/istioctl"
$ISTIO version

# This makes sure the resources created by Istio and not managed by terraform are cleaned up properly.
$ISTIO uninstall --purge -y

TARGET_DIR_RELATIVE="$SCRIPT_DIR/../deploy/_tf"
TARGET_DIR_ABSOLUTE=$(realpath "$TARGET_DIR_RELATIVE")
$TF_CMD -chdir=$TARGET_DIR_ABSOLUTE destroy -auto-approve

print_info "Cleanup completed! Check the output above for any errors."