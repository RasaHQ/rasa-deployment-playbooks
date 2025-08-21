set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"

#Add the Helm repo to your local machine so it can find the installation Helm chart, which enables automated installation:
print_info "Adding the Helm repo for httpbin..."
helm repo add matheusfm https://matheusfm.dev/charts --force-update

# We'll create a new Kubernetes namespace for httpbin so it can be isolated from the rest of our deployments. This is a good practice for organisation and security:
print_info "Creating a new Kubernetes namespace for httpbin..."
kubectl create ns httpbin
kubectl label namespace httpbin istio-injection=enabled
print_info "Httpbin namespace created and labeled for Istio injection!"

# Substitute the values in the template file with the actual values:
envsubst < $SCRIPT_DIR/test-ingress-httpbin-values.template.yaml > $SCRIPT_DIR/test-ingress-httpbin-values.yaml
envsubst < $SCRIPT_DIR/test-ingress-certificate.template.yaml > $SCRIPT_DIR/test-ingress-certificate.yaml

# Install the httpbin Helm chart:
print_info "Installing the httpbin Helm chart..."
helm upgrade --install -n httpbin httpbin matheusfm/httpbin -f $SCRIPT_DIR/test-ingress-httpbin-values.yaml

# Wait for the certificate to be ready:
print_info "Creating the certificate..."
kubectl apply -f $SCRIPT_DIR/test-ingress-certificate.yaml
print_info "Waiting for the certificate to be ready for use..."
kubectl wait -n istio-system --for=condition=Ready=true certificate/httpbin --timeout=120s

# Test the ingress:
print_info "Testing the ingress..."
print_info "Waiting for DNS propagation..."
sleep 60

# Test the curl command and capture the exit code
if curl -f -LI https://httpbin.$DOMAIN/ > /dev/null 2>&1; then
    print_info "Ingress tested successfully!"

    # Delete the httpbin deployment:
    print_info "Cleaning up after testing..."
    helm delete httpbin -n httpbin
    print_info "Httpbin deployment deleted!"
    kubectl delete certificate -n istio-system httpbin
    kubectl delete namespace httpbin
    print_info "Httpbin certificate deleted!"
    print_info "Cleanup complete!"
else
    print_info "Test failed! The ingress is not responding correctly. Resources will not be cleaned up for debugging purposes."
    print_info ""
    print_info "Suggested debugging steps:"
    print_info "1. Check if the httpbin pod is running:"
    print_info "   kubectl get pods -n httpbin"
    print_info ""
    print_info "2. Check if the service is created:"
    print_info "   kubectl get svc -n httpbin"
    print_info ""
    print_info "3. Check if the ingress is configured:"
    print_info "   kubectl get ingress -n httpbin"
    print_info ""
    print_info "4. Check if the certificate is ready:"
    print_info "   kubectl get certificate -n istio-system httpbin"
    print_info ""
    print_info "5. Check DNS resolution:"
    print_info "   nslookup httpbin.$DOMAIN"
    print_info ""
    print_info "6. Check Istio proxy status:"
    print_info "   kubectl get pods -n istio-system"
    print_info ""
fi
