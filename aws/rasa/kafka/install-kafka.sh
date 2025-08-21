set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"

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

# Create a namespace for all the Rasa products to live in
kubectl create namespace $NAMESPACE
kubectl label namespace $NAMESPACE istio-injection=enabled

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
print_info "Starting a Kafka client to test authentication and create topics..."
kubectl run kafka-client --restart='Never' --image docker.io/bitnami/kafka:3.4.0-debian-11-r15 --namespace $NAMESPACE \
--env="KAFKA_OPTS=-Djava.security.auth.login.config=/tmp/kafka_jaas.conf" \
--env="NAMESPACE=$NAMESPACE" \
--command -- sleep infinity

print_info "Waiting for the Kafka client pod to be ready..."
kubectl wait --for=condition=Ready pod/kafka-client --namespace $NAMESPACE --timeout=60s

print_info "Ready! Copying configuration files into the pod so we can authenticate..."
kubectl cp --namespace $NAMESPACE $SCRIPT_DIR/client.properties kafka-client:/tmp/client.properties
kubectl cp --namespace $NAMESPACE $SCRIPT_DIR/kafka_jaas.conf kafka-client:/tmp/kafka_jaas.conf

print_info "Checking Kafka service is running..."
kubectl get svc -n $NAMESPACE | grep kafka

print_info "Kafka service is running! Creating Kafka topics..."
print_info "It's normal to see connection errors here, as the client is not yet connected to the Kafka cluster. You should eventually see the topics created."

kubectl exec kafka-client --namespace $NAMESPACE -- kafka-topics.sh \
   --bootstrap-server kafka.$NAMESPACE.svc.cluster.local:9092 \
   --command-config /tmp/client.properties \
   --create --topic rasa --if-not-exists

kubectl exec kafka-client --namespace $NAMESPACE -- kafka-topics.sh \
   --bootstrap-server kafka.$NAMESPACE.svc.cluster.local:9092 \
   --command-config /tmp/client.properties \
   --create --topic rasa-events-dlq --if-not-exists

print_info "Listing all topics:"
kubectl exec kafka-client --namespace $NAMESPACE -- kafka-topics.sh \
    --bootstrap-server kafka.$NAMESPACE.svc.cluster.local:9092 \
    --command-config /tmp/client.properties \
    --list

print_info "Cleaning up..."
kubectl delete pod kafka-client --namespace $NAMESPACE

print_info "Topic creation completed and temporary pod cleaned up."