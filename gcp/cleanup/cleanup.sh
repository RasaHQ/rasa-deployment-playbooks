set -e

echo "Starting cleanup of GCP infrastructure..."

echo "Deleting PostgreSQL instance..."
gcloud sql instances delete $NAME

echo "Deleting GKE cluster..."
gcloud container clusters delete $NAME --region=$REGION

echo "Deleting Redis instance..."
gcloud redis instances delete $NAME --region=$REGION 

echo "Removing local kubeconfig file..."
rm ./kubeconfig
echo "Local kubeconfig file removed."

echo "Deleting Cloud Storage buckets..."
gcloud storage buckets delete gs://$MODEL_BUCKET
gcloud storage buckets delete gs://$STUDIO_BUCKET

echo "Deleting service accounts..."
gcloud iam service-accounts delete $NAME-dns@$PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts delete $NAME-gke@$PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts delete $NAME-assistant@$PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts delete $NAME-studio@$PROJECT_ID.iam.gserviceaccount.com

echo "Deleting VPC peering connection..."
gcloud services vpc-peerings delete --network=$NAME  --service=servicenetworking.googleapis.com

echo "Deleting private service access address..."
gcloud compute addresses delete $NAME --global

echo "Deleting VPC subnets..."
gcloud compute networks subnets delete $NAME --region $REGION

echo "Deleting VPC network..."
gcloud compute networks delete $NAME

echo "Cleanup completed! Check the output above for any errors."