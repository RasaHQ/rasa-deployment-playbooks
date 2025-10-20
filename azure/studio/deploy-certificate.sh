set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"
source "$SCRIPT_DIR/../utils/common.sh"

auth_to_k8s

envsubst < $SCRIPT_DIR/certificate.template.yaml > $SCRIPT_DIR/certificate.yaml
kubectl apply -f $SCRIPT_DIR/certificate.yaml
print_info "Certificate deployed successfully!"

print_info "You should now be able to access Rasa Studio at https://studio.$DOMAIN. It may take a few minutes for the certificate to issue and be fully available."