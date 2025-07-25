# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#Add the Helm repo to your local machine so it can find the installation Helm chart, which enables automated installation:
echo "Adding the Helm repo for httpbin..."
helm repo add matheusfm https://matheusfm.dev/charts --force-update

# We'll create a new Kubernetes namespace for httpbin so it can be isolated from the rest of our deployments. This is a good practice for organisation and security:
echo "Creating a new Kubernetes namespace for httpbin..."
kubectl create ns httpbin
kubectl label namespace httpbin istio-injection=enabled
echo "Httpbin namespace created and labeled for Istio injection!"

# Substitute the values in the template file with the actual values:
envsubst < $SCRIPT_DIR/test-ingress-httpbin-values.template.yaml > $SCRIPT_DIR/test-ingress-httpbin-values.yaml
envsubst < $SCRIPT_DIR/test-ingress-certificate.template.yaml > $SCRIPT_DIR/test-ingress-certificate.yaml

# Install the httpbin Helm chart:
echo "Installing the httpbin Helm chart..."
helm upgrade --install -n httpbin httpbin matheusfm/httpbin -f $SCRIPT_DIR/test-ingress-httpbin-values.yaml

# Wait for the certificate to be ready:
echo "Creating the certificate..."
kubectl apply -f $SCRIPT_DIR/test-ingress-certificate.yaml
echo "Waiting for the certificate to be ready for use..."
kubectl wait -n istio-system --for=condition=Ready=true certificate/httpbin --timeout=60s
echo "Certificate is ready!"

# Test the ingress:
echo "Testing the ingress..."
echo "Waiting for DNS propagation..."
sleep 60

# Test the curl command and capture the exit code
if curl -f -LI https://httpbin.$DOMAIN/ > /dev/null 2>&1; then
    echo "Ingress tested successfully!"

    # Delete the httpbin deployment:
    echo "Cleaning up after testing..."
    helm delete httpbin -n httpbin
    echo "Httpbin deployment deleted!"
    kubectl delete certificate -n istio-system httpbin
    kubectl delete namespace httpbin
    echo "Httpbin certificate deleted!"
    echo "Cleanup complete!"
else
    echo "Test failed! The ingress is not responding correctly. Resources will not be cleaned up for debugging purposes."
    echo ""
    echo "Suggested debugging steps:"
    echo "1. Check if the httpbin pod is running:"
    echo "   kubectl get pods -n httpbin"
    echo ""
    echo "2. Check if the service is created:"
    echo "   kubectl get svc -n httpbin"
    echo ""
    echo "3. Check if the ingress is configured:"
    echo "   kubectl get ingress -n httpbin"
    echo ""
    echo "4. Check if the certificate is ready:"
    echo "   kubectl get certificate -n istio-system httpbin"
    echo ""
    echo "5. Check DNS resolution:"
    echo "   nslookup httpbin.$DOMAIN"
    echo ""
    echo "6. Check Istio proxy status:"
    echo "   kubectl get pods -n istio-system"
    echo ""
fi
