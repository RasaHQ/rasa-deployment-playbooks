set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"

print_info "Generating kubeconfig to authenticate with GKE cluster..."
# To be able to interact with the GKE cluster we deployed earlier, we need to obtain the credentials for it. These credentials are saved in a file called kubeconfig which the gcloud CLI can generate for us and kubectl can use.
# Ensure we've got a path setup for the kubeconfig file:
export KUBECONFIG=$(pwd)/kubeconfig
print_info "Kubeconfig path:  $KUBECONFIG"
rm -f $KUBECONFIG
#Retrieve the credentials for the cluster using the gcloud CLI:
gcloud container clusters get-credentials $NAME --region=$REGION 
# Next, validate that the credentials work - we should see information about our cluster output here if everything has worked.
print_info "Kubeconfig generated successfully! Printing cluster info below, if you see output here, authentication was successful."
kubectl cluster-info
kubectl get ns

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

# Create DNS Zone
# We will now create a DNS zone on Google Cloud. We'll use this to map our own domain name like rasa.example.com onto the Rasa products that we deploy and ensure they can be accessed by domain name.
gcloud dns managed-zones create $DNS_ZONE \
  --dns-name=$DOMAIN \
  --description="$NAME"

# You will now need to update some DNS records on your domain. You will need to find where your DNS is configured for your domain - this may be a cloud provider like AWS or a domain registrar like GoDaddy or Cloudflare.
# Retrieve the the nameservers of the zone you have just created in GCP:
print_info "Retrieving the nameservers of the zone you have just created in GCP..."
print_info "You must now create an NS record for your domain $DOMAIN with the following values:"
gcloud dns record-sets list --zone=$DNS_ZONE --name=$DOMAIN --type=NS