# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Generating kubeconfig to authenticate with GKE cluster..."
# To be able to interact with the GKE cluster we deployed earlier, we need to obtain the credentials for it. These credentials are saved in a file called kubeconfig which the gcloud CLI can generate for us and kubectl can use.
# Ensure we've got a path setup for the kubeconfig file:
export KUBECONFIG=$(pwd)/kubeconfig
echo "Kubeconfig path:  $KUBECONFIG"
rm -f $KUBECONFIG
#Retrieve the credentials for the cluster using the gcloud CLI:
gcloud container clusters get-credentials $NAME --region=$REGION 
# Next, validate that the credentials work - we should see information about our cluster output here if everything has worked.
echo "Kubeconfig generated successfully! Printing cluster info below, if you see output here, authentication was successful."
kubectl cluster-info
kubectl get ns

# Configure certificate 
echo "Configuring certificate..."
envsubst < $SCRIPT_DIR/certificate.template.yaml > $SCRIPT_DIR/certificate.yaml

echo "Deploying certificate..."
kubectl apply -f $SCRIPT_DIR/certificate.yaml

# Configure ingress
echo "Configuring ingress..."
envsubst < $SCRIPT_DIR/ingress.template.yaml > $SCRIPT_DIR/ingress.yaml

echo "Deploying ingress..."
kubectl apply -f $SCRIPT_DIR/ingress.yaml

echo "You should now be able to access the Rasa assistant at https://assistant.$DOMAIN. It may take a few minutes for the certificate to issue and be fully available."