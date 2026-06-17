set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../../utils/common.sh"

validate_variables NAME NAMESPACE DOMAIN REGION

print_info "Generating kubeconfig to authenticate with EKS cluster..."
# To be able to interact with the EKS cluster we deployed earlier, we need to obtain the credentials for it. These credentials are saved in a file called kubeconfig which the AWS CLI can generate for us and kubectl can use.
# Ensure we've got a path setup for the kubeconfig file:
export KUBECONFIG=$(pwd)/kubeconfig
print_info "Kubeconfig path:  $KUBECONFIG"
rm -f $KUBECONFIG
#Retrieve the credentials for the cluster using the AWS CLI:
aws eks update-kubeconfig --region $REGION --name $NAME
# Next, validate that the credentials work - we should see information about our cluster output here if everything has worked.
print_info "Kubeconfig generated successfully! Printing cluster info below, if you see output here, authentication was successful."
kubectl cluster-info
kubectl get ns

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

print_info "Configuring A2A sticky routing (contextId hash + gateway cookie)..."
envsubst '${NAME} ${NAMESPACE} ${DOMAIN}' < "$SCRIPT_DIR/a2a-destination-rule.template.yaml" > "$SCRIPT_DIR/a2a-destination-rule.yaml"
envsubst '${NAME} ${NAMESPACE} ${DOMAIN}' < "$SCRIPT_DIR/a2a-envoyfilter.template.yaml" > "$SCRIPT_DIR/a2a-envoyfilter.yaml"

print_info "Deploying A2A DestinationRule..."
kubectl apply -f "$SCRIPT_DIR/a2a-destination-rule.yaml"

print_info "Deploying A2A EnvoyFilter on istio-ingressgateway..."
kubectl apply -f "$SCRIPT_DIR/a2a-envoyfilter.yaml"

print_info "You should now be able to access the Rasa assistant at https://assistant.$DOMAIN. It may take a few minutes for the certificate to issue and be fully available."
print_info "A2A JSON-RPC traffic is load-balanced by x-a2a-context-id (body contextId, X-A2A-Context-Id header, or a2a-context-id cookie)."