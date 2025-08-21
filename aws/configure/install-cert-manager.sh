set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"

#Add the Helm repo to your local machine so it can find the installation Helm chart, which enables automated installation:
print_info "Adding the Helm repo for cert-manager..."
helm repo add jetstack https://charts.jetstack.io --force-update

# Substitute the values in the template file with the actual values:
envsubst < $SCRIPT_DIR/cert-manager-values.template.yaml > $SCRIPT_DIR/cert-manager-values.yaml

# We'll create a new Kubernetes namespace for cert-manager so it can be isolated from the rest of our deployments. This is a good practice for organisation and security:
print_info "Creating a new Kubernetes namespace for cert-manager..."
kubectl create ns cert-manager
kubectl label namespace cert-manager istio-injection=enabled
print_info "Cert-manager namespace created and labeled for Istio injection!"

# Install cert-manager using the configuration we've just created into its new namespace:
print_info "Installing cert-manager using the configuration we've just created into its new namespace..."
helm upgrade --install -n cert-manager cert-manager jetstack/cert-manager -f $SCRIPT_DIR/cert-manager-values.yaml

# Configure cert-manager to issue LetsEncrypt certificates:
print_info "Configuring cert-manager to issue LetsEncrypt certificates..."
envsubst < $SCRIPT_DIR/cert-manager-certificate-issuer.template.yaml > $SCRIPT_DIR/cert-manager-certificate-issuer.yaml
kubectl apply -f $SCRIPT_DIR/cert-manager-certificate-issuer.yaml
print_info "Cert-manager configured to issue LetsEncrypt certificates!"

# Wait for the ClusterIssuer to be created successfully:
print_info "Validating that the ClusterIssuer was created successfully..."
print_info "Waiting for ClusterIssuer letsencrypt to become Ready..."
kubectl wait --for=condition=Ready clusterissuer/letsencrypt --timeout=180s
print_info "ClusterIssuer letsencrypt is Ready:"
kubectl get clusterissuer letsencrypt
