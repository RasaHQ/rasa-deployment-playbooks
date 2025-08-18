set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Generating kubeconfig to authenticate with EKS cluster..."
# To be able to interact with the EKS cluster we deployed earlier, we need to obtain the credentials for it. These credentials are saved in a file called kubeconfig which the AWS CLI can generate for us and kubectl can use.
# Ensure we've got a path setup for the kubeconfig file:
export KUBECONFIG=$(pwd)/kubeconfig
echo "Kubeconfig path:  $KUBECONFIG"
rm -f $KUBECONFIG
#Retrieve the credentials for the cluster using the AWS CLI:
aws eks update-kubeconfig --region $REGION --name $NAME
# Next, validate that the credentials work - we should see information about our cluster output here if everything has worked.
echo "Kubeconfig generated successfully! Printing cluster info below, if you see output here, authentication was successful."
kubectl cluster-info
kubectl get ns

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Setting up Istio..."
# Download and install the istioctl tool for managing Istio, the service mesh that will ensure that communication between different Rasa product components is encrypted in transit, on your cluster:
curl -L https://istio.io/downloadIstio | sh -
# Configure required environment variables:
export ISTIO_DIR=$(ls | grep -v istio-operator.yaml | grep istio- | sort --version-sort | tail -1)
echo "Istio dir:  $ISTIO_DIR"
export ISTIO="$ISTIO_DIR/bin/istioctl"
$ISTIO version

# Install Istio onto Your Cluster
# Use our preconfigured YAML files to install Istio onto your cluster.
echo "Installing Istio on your cluster..."
$ISTIO install --set profile=demo --skip-confirmation -f "$SCRIPT_DIR/istio-operator.yaml"

# Here we'll create an Ingress Class that will help us handle network traffic coming inbound to the Rasa products.
echo "Creating the Istio Ingress Class on your cluster..."
kubectl apply -f "$SCRIPT_DIR/istio-ingress-class.yaml"

# You will now need to update some DNS records on your domain. You will need to find where your DNS is configured for your domain - this may be a cloud provider like AWS or a domain registrar like GoDaddy or Cloudflare.
# Retrieve the the nameservers of the zone you have just created in AWS:
echo "Retrieving the nameservers of the zone you have just created in AWS..."
echo "You must now create an NS record for your domain $DOMAIN with the following values:"
TARGET_DIR_RELATIVE="$SCRIPT_DIR/../deploy/_tf"
TARGET_DIR_ABSOLUTE=$(realpath "$TARGET_DIR_RELATIVE")
$TF_CMD -chdir=$TARGET_DIR_ABSOLUTE output dns_name_servers