set-e

# Fail on errors so you can debug
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p $SCRIPT_DIR/_tf

# Substitute the values in the template file with the actual values:
envsubst < $SCRIPT_DIR/main.tf.template > $SCRIPT_DIR/_tf/main.tf

# Deploy the infrastructure using Terraform or OpenTofu depending on the value of $TF_CMD
$TF_CMD -chdir=$SCRIPT_DIR/_tf init
$TF_CMD -chdir=$SCRIPT_DIR/_tf plan
$TF_CMD -chdir=$SCRIPT_DIR/_tf apply -auto-approve
