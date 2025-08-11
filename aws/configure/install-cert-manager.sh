set -e
# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#Add the Helm repo to your local machine so it can find the installation Helm chart, which enables automated installation:
echo "Adding the Helm repo for cert-manager..."
helm repo add jetstack https://charts.jetstack.io --force-update

# Substitute the values in the template file with the actual values:
envsubst < $SCRIPT_DIR/cert-manager-values.template.yaml > $SCRIPT_DIR/cert-manager-values.yaml

# We'll create a new Kubernetes namespace for cert-manager so it can be isolated from the rest of our deployments. This is a good practice for organisation and security:
echo "Creating a new Kubernetes namespace for cert-manager..."
kubectl create ns cert-manager
kubectl label namespace cert-manager istio-injection=enabled
echo "Cert-manager namespace created and labeled for Istio injection!"

# Install cert-manager using the configuration we've just created into its new namespace:
echo "Installing cert-manager using the configuration we've just created into its new namespace..."
helm upgrade --install -n cert-manager cert-manager jetstack/cert-manager -f $SCRIPT_DIR/cert-manager-values.yaml

# Configure cert-manager to issue LetsEncrypt certificates:
echo "Configuring cert-manager to issue LetsEncrypt certificates..."
envsubst < $SCRIPT_DIR/cert-manager-certificate-issuer.template.yaml > $SCRIPT_DIR/cert-manager-certificate-issuer.yaml
kubectl apply -f $SCRIPT_DIR/cert-manager-certificate-issuer.yaml
echo "Cert-manager configured to issue LetsEncrypt certificates!"

# Validate that the ClusterIssuer was created successfully:
echo "Validating that the ClusterIssuer was created successfully..."
echo "You should see a ClusterIssuer named letsencrypt with a status of Ready:"
kubectl get ClusterIssuer letsencrypt
