set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../../utils/common.sh"
source "$SCRIPT_DIR/../../utils/common.sh"

auth_to_k8s

# Configure certificate 
print_info "Configuring certificate..."
envsubst < $SCRIPT_DIR/certificate.template.yaml > $SCRIPT_DIR/certificate.yaml

print_info "Deploying certificate..."
kubectl apply -f $SCRIPT_DIR/certificate.yaml

# Configure ingress
print_info "Configuring ingress..."
envsubst < $SCRIPT_DIR/ingress.template.yaml > $SCRIPT_DIR/ingress.yaml

print_info "Deploying ingress..."
kubectl apply -f $SCRIPT_DIR/ingress.yaml

print_info "You should now be able to access the Rasa assistant at https://assistant.$DOMAIN. It may take a few minutes for the certificate to issue and be fully available."