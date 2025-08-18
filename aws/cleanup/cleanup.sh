set -e
echo "Starting cleanup of AWS infrastructure..."

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TARGET_DIR_RELATIVE="$SCRIPT_DIR/../deploy/_tf"
TARGET_DIR_ABSOLUTE=$(realpath "$TARGET_DIR_RELATIVE")
$TF_CMD -chdir=$TARGET_DIR_ABSOLUTE destroy -auto-approve

echo "Cleanup completed! Check the output above for any errors."