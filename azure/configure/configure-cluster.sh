set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"
source "$SCRIPT_DIR/../utils/common.sh"

auth_to_k8s

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_info "Setting up Istio..."
# Download and install the istioctl tool for managing Istio, the service mesh that will ensure that communication between different Rasa product components is encrypted in transit, on your cluster:
curl -L https://istio.io/downloadIstio | sh -
# Configure required environment variables:
export ISTIO_DIR=$(ls | grep -v istio-operator.yaml | grep istio- | sort --version-sort | tail -1)
print_info "Istio dir:  $ISTIO_DIR"
export ISTIO="$ISTIO_DIR/bin/istioctl"
$ISTIO version

# Install Istio onto Your Cluster
# Use our preconfigured YAML files to install Istio onto your cluster.
print_info "Installing Istio on your cluster..."
$ISTIO install --set profile=demo --skip-confirmation -f "$SCRIPT_DIR/istio-operator.yaml"

# Here we'll create an Ingress Class that will help us handle network traffic coming inbound to the Rasa products.
print_info "Creating the Istio Ingress Class on your cluster..."
kubectl apply -f "$SCRIPT_DIR/istio-ingress-class.yaml"

# You will now need to update some DNS records on your domain. You will need to find where your DNS is configured for your domain - this may be a cloud provider like AWS or a domain registrar like GoDaddy or Cloudflare.
print_info "Retrieving the nameservers of the zone you have just created in Azure..."
print_info "You must now create an NS record for your domain $DOMAIN with the following values:"
TARGET_DIR_RELATIVE="$SCRIPT_DIR/../deploy/_tf"
TARGET_DIR_ABSOLUTE=$(realpath "$TARGET_DIR_RELATIVE")
$TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output dns_name_servers