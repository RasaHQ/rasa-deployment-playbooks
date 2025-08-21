set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"

#Add the Helm repo to your local machine so it can find the installation Helm chart, which enables automated installation:
print_info "Adding the Helm repo for external-dns..."
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

# Substitute the values in the template file with the actual values:
envsubst < $SCRIPT_DIR/external-dns-values.template.yaml > $SCRIPT_DIR/external-dns-values.yaml

# We'll create a new Kubernetes namespace for external-dns so it can be isolated from the rest of our deployments. This is a good practice for organisation and security:
print_info "Creating a new Kubernetes namespace for external-dns..."
kubectl create ns external-dns
kubectl label namespace external-dns istio-injection=enabled

# Install the external-dns Helm chart:
print_info "Installing the external-dns Helm chart..."
helm upgrade --install -n external-dns external-dns external-dns/external-dns  -f $SCRIPT_DIR/external-dns-values.yaml