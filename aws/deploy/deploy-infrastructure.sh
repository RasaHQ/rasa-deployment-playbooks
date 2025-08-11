# Fail on errors so you can debug
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Substitute the values in the template file with the actual values:
envsubst < $SCRIPT_DIR/main.tf.template > $SCRIPT_DIR/main.tf

# Deploy the infrastructure using Terraform or OpenTofu depending on the value of $TF_COMMAND
$TF_COMMAND init
$TF_COMMAND plan
$TF_COMMAND apply -auto-approve
