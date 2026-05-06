#!/usr/bin/env bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../../utils/common.sh"

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

# Create a namespace for all the Rasa products to live in (idempotent on rerun)
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace $NAMESPACE istio-injection=enabled --overwrite

# Create a storage class for the Kafka cluster
kubectl apply -f $SCRIPT_DIR/storage-class.yaml

# Create a random 16 character password for Kafka to use for authentication and then inject it into the Kafka configuration file.
print_info "Generating a random 16 character password for Kafka to use for authentication..."
export KAFKA_PASSWORD=$(openssl rand -hex 16)
envsubst < $SCRIPT_DIR/kafka.template.yaml > $SCRIPT_DIR/kafka.yaml
print_info "Kafka password: $KAFKA_PASSWORD"
print_info "Kafka configuration file generated successfully!"

# We'll fetch the automatically generated password from the previous step, and then use it to create a couple of configuration files locally that act as configuration for Rasa to be able to connect to Kafka
print_info "Installing Kafka to the cluster..."
helm repo add bitnami https://charts.bitnami.com/bitnami
print_info "First, uninstalling existing Kafka from the cluster..."
# We ignore an error when there is no existing Kafka installation
helm uninstall kafka -n $NAMESPACE || true
helm upgrade --install -n $NAMESPACE kafka bitnami/kafka -f $SCRIPT_DIR/kafka.yaml --version 32.3.2
print_info "Kafka installed successfully!"

print_info "Generating client configuration for Rasa to use to connect to Kafka..."
envsubst < $SCRIPT_DIR/client.properties.template > $SCRIPT_DIR/client.properties
envsubst < $SCRIPT_DIR/kafka_jaas.conf.template > $SCRIPT_DIR/kafka_jaas.conf
print_info "Client configuration for Rasa to use to connect to Kafka generated successfully!"

# Next, we need to create Kafka topics that Rasa will use to send data through. We'll use the configuration files we've just generated which will also confirm that all the authentication is working properly.
# Use a per-run-unique pod name so reruns don't race against a still-Terminating pod from a previous run.
KAFKA_CLIENT_POD="kafka-client-$(openssl rand -hex 4)"

# Combined cleanup + error-reporting EXIT trap.
# Replaces the EXIT trap installed by utils/common.sh; we re-emit its "Script failed!"
# message on non-zero exit so we don't lose that behaviour.
trap 'rc=$?
  kubectl delete pod "$KAFKA_CLIENT_POD" --namespace "$NAMESPACE" --ignore-not-found=true >/dev/null 2>&1 || true
  [ $rc -ne 0 ] && print_error "Script failed!" >&2
  exit $rc' EXIT

print_info "Starting a Kafka client to test authentication and create topics..."
kubectl run "$KAFKA_CLIENT_POD" --restart='Never' --image bitnamilegacy/kafka:3.4.0-debian-11-r15 --namespace $NAMESPACE \
--env="KAFKA_OPTS=-Djava.security.auth.login.config=/tmp/kafka_jaas.conf" \
--env="NAMESPACE=$NAMESPACE" \
--command -- sleep infinity

print_info "Waiting for the Kafka client pod to be ready..."
kubectl wait --for=condition=Ready pod/"$KAFKA_CLIENT_POD" --namespace $NAMESPACE --timeout=60s

print_info "Ready! Copying configuration files into the pod so we can authenticate..."
kubectl cp --namespace $NAMESPACE $SCRIPT_DIR/client.properties "$KAFKA_CLIENT_POD":/tmp/client.properties
kubectl cp --namespace $NAMESPACE $SCRIPT_DIR/kafka_jaas.conf "$KAFKA_CLIENT_POD":/tmp/kafka_jaas.conf

print_info "Checking Kafka service is running..."
kubectl get svc -n $NAMESPACE | grep kafka

print_info "Waiting for Kafka brokers' SASL endpoint to be ready before creating topics..."
print_info "(KRaft controller quorum can take 60-300s to settle. The Pod's readiness probe passes earlier"
print_info " — well before SASL handshakes succeed — so we poll explicitly with kafka-topics --list until it works.)"
KAFKA_READY=false
for i in $(seq 1 30); do
  if kubectl exec "$KAFKA_CLIENT_POD" --namespace $NAMESPACE -- kafka-topics.sh \
       --bootstrap-server kafka.$NAMESPACE.svc.cluster.local:9092 \
       --command-config /tmp/client.properties \
       --list >/dev/null 2>&1; then
    print_info "Kafka SASL endpoint ready (attempt $i/30)."
    KAFKA_READY=true
    break
  fi
  sleep 10
done
if [ "$KAFKA_READY" != "true" ]; then
  print_error "Kafka brokers did not become SASL-ready within 5 minutes. Inspect 'kubectl -n $NAMESPACE logs kafka-controller-0' to diagnose."
  exit 1
fi

print_info "Creating Kafka topics..."

kubectl exec "$KAFKA_CLIENT_POD" --namespace $NAMESPACE -- kafka-topics.sh \
   --bootstrap-server kafka.$NAMESPACE.svc.cluster.local:9092 \
   --command-config /tmp/client.properties \
   --create --topic rasa --if-not-exists

kubectl exec "$KAFKA_CLIENT_POD" --namespace $NAMESPACE -- kafka-topics.sh \
   --bootstrap-server kafka.$NAMESPACE.svc.cluster.local:9092 \
   --command-config /tmp/client.properties \
   --create --topic rasa-events-dlq --if-not-exists

print_info "Listing all topics:"
kubectl exec "$KAFKA_CLIENT_POD" --namespace $NAMESPACE -- kafka-topics.sh \
    --bootstrap-server kafka.$NAMESPACE.svc.cluster.local:9092 \
    --command-config /tmp/client.properties \
    --list

print_info "Cleaning up..."
kubectl delete pod "$KAFKA_CLIENT_POD" --namespace $NAMESPACE --ignore-not-found=true

print_info "Topic creation completed and temporary pod cleaned up."
