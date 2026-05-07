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

print_info "Starting cleanup of AWS infrastructure..."

print_info "Uninstalling Istio..."

export ISTIO_DIR=$(ls | grep -v istio-operator.yaml | grep istio- | sort --version-sort | tail -1)
print_info "Istio dir:  $ISTIO_DIR"
export ISTIO="$ISTIO_DIR/bin/istioctl"
$ISTIO version

# This makes sure the resources created by Istio and not managed by terraform are cleaned up properly.
$ISTIO uninstall --purge -y

TARGET_DIR_RELATIVE="$SCRIPT_DIR/../deploy/_tf"
TARGET_DIR_ABSOLUTE=$(realpath "$TARGET_DIR_RELATIVE")
$TF_CMD -chdir=$TARGET_DIR_ABSOLUTE destroy -auto-approve

# Delete EBS volumes left over from dynamic PVC provisioning. The EBS CSI driver
# creates these in response to PVCs (e.g. from the Kafka StatefulSet), but
# terraform doesn't track them in state, so `terraform destroy` doesn't remove
# them — they end up as orphan `available` volumes after cleanup, costing money
# and cluttering the account. This sweep runs AFTER terraform destroy and only
# matches volumes tagged with this deployment's NAME prefix and in `available`
# state, so it can never touch a live volume from another deployment.
print_info "Sweeping orphan EBS volumes left over from dynamic PVC provisioning..."
ORPHAN_VOLS=$(aws ec2 describe-volumes \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=${NAME}-dynamic-pvc-*" "Name=status,Values=available" \
  --query 'Volumes[].VolumeId' \
  --output text)
if [ -n "$ORPHAN_VOLS" ]; then
  for vol in $ORPHAN_VOLS; do
    print_info "  deleting $vol"
    aws ec2 delete-volume --region "$REGION" --volume-id "$vol" || true
  done
else
  print_info "  none found"
fi

print_info "Cleanup completed! Check the output above for any errors."