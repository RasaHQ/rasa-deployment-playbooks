# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/../../utils/common.sh"

print_info "Starting cleanup of GCP infrastructure..."

print_info "Deleting PostgreSQL instance..."
gcloud sql instances delete $NAME

print_info "Deleting GKE cluster..."
gcloud container clusters delete $NAME --region=$REGION

print_info "Deleting Redis instance..."
gcloud redis instances delete $NAME --region=$REGION 

print_info "Removing local kubeconfig file..."
rm ./kubeconfig
print_info "Local kubeconfig file removed."

print_info "Deleting Cloud Storage buckets..."
gcloud storage buckets delete gs://$MODEL_BUCKET
gcloud storage buckets delete gs://$STUDIO_BUCKET

print_info "Deleting service accounts..."
gcloud iam service-accounts delete $NAME-dns@$PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts delete $NAME-gke@$PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts delete $NAME-assistant@$PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts delete $NAME-studio@$PROJECT_ID.iam.gserviceaccount.com

print_info "Deleting VPC peering connection..."
gcloud services vpc-peerings delete --network=$NAME  --service=servicenetworking.googleapis.com

print_info "Deleting private service access address..."
gcloud compute addresses delete $NAME --global

print_info "Deleting VPC subnets..."
gcloud compute networks subnets delete $NAME --region $REGION

print_info "Deleting VPC network..."
gcloud compute networks delete $NAME

print_info "Cleanup completed! Check the output above for any errors."