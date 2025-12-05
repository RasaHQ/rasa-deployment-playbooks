set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../../utils/common.sh"
source "$SCRIPT_DIR/../../utils/common.sh"

auth_to_k8s

# Create a namespace for all the Rasa products to live in
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE istio-injection=enabled

print_info "Adding Helm repo for Kafka..."
helm repo add strimzi https://strimzi.io/charts/
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator --version 0.47.0  -n "$NAMESPACE" --wait

envsubst < "$SCRIPT_DIR/kafka.template.yaml" > "$SCRIPT_DIR/kafka.yaml"
print_info "Installing Kafka to the cluster..."
kubectl apply -f "$SCRIPT_DIR/kafka.yaml" -n "$NAMESPACE"
