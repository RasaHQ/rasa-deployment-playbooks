# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"

print_info "Starting cleanup of AWS infrastructure..."

print_info "Finding and deleting EC2 Classic Load Balancers associated with the EKS cluster..."
ALL_LB_NAMES=$(aws elb describe-load-balancers --query "LoadBalancerDescriptions[].LoadBalancerName" --output text)
LOAD_BALANCERS=""
echo $ALL_LB_NAMES
for lb_name in $ALL_LB_NAMES; do
  echo $lb_name
  TAGS=$(aws elb describe-tags --load-balancer-names "$lb_name" --query "TagDescriptions[0].Tags[?Key=='kubernetes.io/cluster/$NAME'].Value" --output text)
  if [ "$TAGS" = "owned" ]; then
    LOAD_BALANCERS="$LOAD_BALANCERS $lb_name"
  fi
done
LOAD_BALANCERS=$(echo "$LOAD_BALANCERS" | xargs)
if [ -n "$LOAD_BALANCERS" ]; then
  if [ "$(echo "$LOAD_BALANCERS" | wc -l)" -gt 1 ]; then
    print_error "Multiple load balancers found. Please delete them manually:"
    echo "$LOAD_BALANCERS"
    exit 1
  fi
  print_info "Deleting load balancer: $LOAD_BALANCERS"
  aws elb delete-load-balancer --load-balancer-name "$LOAD_BALANCERS"
  print_info "Load balancer deleted successfully."
else
  print_info "No EC2 Classic Load Balancers found associated with the EKS cluster."
fi

TARGET_DIR_RELATIVE="$SCRIPT_DIR/../deploy/_tf"
TARGET_DIR_ABSOLUTE=$(realpath "$TARGET_DIR_RELATIVE")
$TF_CMD -chdir=$TARGET_DIR_ABSOLUTE destroy -auto-approve

print_info "Cleanup completed! Check the output above for any errors."