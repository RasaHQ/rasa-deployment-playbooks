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

envsubst < $SCRIPT_DIR/certificate.template.yaml > $SCRIPT_DIR/certificate.yaml
kubectl apply -f $SCRIPT_DIR/certificate.yaml
echo "Certificate deployed successfully!"