echo "Enabling required services on GCP..."
: '
GCP requires that you enable the services you wish to use in each project before you can deploy infrastructure. You'll need to enable the following APIs & Services by logging into the Google Cloud Web UI and ensuring you're in the correct project:
- [Compute Engine API](https://console.cloud.google.com/apis/library/compute.googleapis.com), for creating the virtual network.
- [Service Networking API](https://console.cloud.google.com/apis/library/servicenetworking.googleapis.com), to allow us to automatically manage networking.
- [Kubernetes Engine API](https://console.developers.google.com/apis/api/container.googleapis.com), to allow us to deploy a Google Kubernetes Engine (GKE) cluster.
- [Cloud SQL API](https://console.developers.google.com/apis/api/sqladmin.googleapis.com), to allow us to deploy a managed Cloud SQL PostgreSQL instance.
- [Google Cloud Memorystore for Redis API ](https://console.developers.google.com/apis/api/redis.googleapis.com), to allow us to deploy a managed Redis instance.
- [Cloud DNS API](https://console.developers.google.com/apis/api/dns.googleapis.com), to allow us to create the required DNS records for the services.
- [IAM API](https://console.developers.google.com/apis/api/iam.googleapis.com), to allow us to manage IAM roles.
'
gcloud services enable \
  compute.googleapis.com \
  servicenetworking.googleapis.com \
  container.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  dns.googleapis.com \
  iam.googleapis.com 
echo "Required services enabled."

echo "Deploying infrastructure..."

echo "Creating VPC network..."
gcloud compute networks create $NAME \
  --bgp-routing-mode=global \
  --subnet-mode=custom
echo "VPC network created."

echo "Creating subnets..."
gcloud compute networks subnets create $NAME \
  --network $NAME \
  --enable-private-ip-google-access \
  --range 10.100.80.0/24 \
  --region $REGION \
  --secondary-range pods=10.100.0.0/18 \
  --secondary-range services=10.100.64.0/20
echo "Subnets created."

echo "Configuring Private Service Access..."
gcloud compute addresses create $NAME \
  --global \
  --purpose=VPC_PEERING \
  --addresses=10.100.96.0 \
  --prefix-length=19 \
  --network=$NAME
echo "Private Service Access configured."

echo "Enabling VPC Peering..."
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=$NAME \
    --network=$NAME
echo "VPC Peering enabled."

echo "Creating GCP Service Account..."
gcloud iam service-accounts create ${NAME}-gke
echo "GCP Service Account created."

echo "Assigning roles to GCP Service Account..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$NAME-gke@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/logging.logWriter" \
  --condition=None
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$NAME-gke@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/monitoring.metricWriter" \
  --condition=None
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$NAME-gke@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudprofiler.agent" \
  --condition=None
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$NAME-gke@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/errorreporting.writer" \
  --condition=None
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$NAME-gke@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/cloudtrace.agent" \
  --condition=None
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$NAME-gke@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/containerregistry.ServiceAgent" \
  --condition=None
echo "Roles assigned to GCP Service Account."

echo "Creating GKE Cluster..."
gcloud container clusters create $NAME \
  --region=$REGION \
  --release-channel=stable \
  --network=$NAME \
  --subnetwork=$NAME \
  --cluster-secondary-range-name=pods \
  --services-secondary-range-name=services \
  --enable-ip-alias \
  --no-enable-insecure-kubelet-readonly-port \
  --addons=HorizontalPodAutoscaling=ENABLED,HttpLoadBalancing=ENABLED \
  --enable-autoscaling \
  --total-max-nodes=21 \
  --maintenance-window="01:00" \
  --machine-type=n2-standard-8 \
  --num-nodes=1 \
  --tags=$NAME \
  --workload-metadata=GKE_METADATA \
  --workload-pool=$PROJECT_ID.svc.id.goog \
  --async
echo "GKE Cluster will continue to deploy in the background..."

echo "Creating DNS Service Account..."
gcloud iam service-accounts create $NAME-dns
echo "DNS Service Account created."

echo "Assigning roles to DNS Service Account..."
gcloud iam service-accounts add-iam-policy-binding $NAME-dns@$PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[external-dns/external-dns]" \
  --role="roles/iam.workloadIdentityUser"

gcloud iam service-accounts add-iam-policy-binding $NAME-dns@$PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[cert-manager/cert-manager]" \
  --role="roles/iam.workloadIdentityUser"
echo "Roles assigned to DNS Service Account."

echo "Creating Rasa Service Account and assigning roles..."
gcloud iam service-accounts create $NAME-assistant

gcloud iam service-accounts add-iam-policy-binding $NAME-assistant@$PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[rasa-assistant/$NAMESPACE]" \
  --role="roles/iam.workloadIdentityUser"
echo "Rasa Service Account created and configured"

echo "Creating Rasa Studio Service Account and assigning roles..."
gcloud iam service-accounts create $NAME-studio

gcloud iam service-accounts add-iam-policy-binding $NAME-studio@$PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[rasa-studio/$NAMESPACE]" \
  --role="roles/iam.workloadIdentityUser"
echo "Rasa Studio Service Account created and configured"

echo "Setting up PostgreSQL instance..."
export NETWORK_LINK=$(gcloud compute networks describe $NAME --format='value(selfLink)')
export NETWORK_LINK="${NETWORK_LINK#'https://www.googleapis.com/compute/v1/'}"
echo "Network link: $NETWORK_LINK"
export PG_VERSION="17"
echo "Creating PostgreSQL instance..."
gcloud sql instances create $NAME \
  --database-version=POSTGRES_${PG_VERSION} \
  --region=$REGION \
  --edition=enterprise \
  --cpu=2 \
  --memory=8GB \
  --availability-type=regional \
  --storage-size=100GB \
  --storage-type=SSD \
  --storage-auto-increase \
  --backup \
  --enable-point-in-time-recovery \
  --database-flags log_min_duration_statement=1000,cloudsql.logical_decoding=On \
  --no-assign-ip \
  --network=$NETWORK_LINK \
  --enable-google-private-path \
  --maintenance-window-day=SUN \
  --maintenance-window-hour=1 \
  --async
echo "PostgreSQL instance will continue to deploy in the background..."

echo "Creating Cloud Storage Buckets..."
gcloud storage buckets create gs://$MODEL_BUCKET \
  --location=US \
  --default-storage-class=MULTI_REGIONAL \
  --uniform-bucket-level-access \
  --public-access-prevention

gcloud storage buckets create gs://$STUDIO_BUCKET \
  --location=US \
  --default-storage-class=MULTI_REGIONAL \
  --uniform-bucket-level-access \
  --public-access-prevention
echo "Cloud Storage Buckets created."

echo "Assigning service accounts access to Cloud Storage Buckets..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$NAME-assistant@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.bucketViewer" \
  --condition=None
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$NAME-studio@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/storage.bucketViewer" \
  --condition=None

gcloud storage buckets add-iam-policy-binding gs://$MODEL_BUCKET \
  --member="serviceAccount:$NAME-assistant@$PROJECT_ID.iam.gserviceaccount.com" \
  --role=roles/storage.objectAdmin \
  --condition=None
gcloud storage buckets add-iam-policy-binding gs://$STUDIO_BUCKET \
  --member="serviceAccount:$NAME-studio@$PROJECT_ID.iam.gserviceaccount.com" \
  --role=roles/storage.objectAdmin \
  --condition=None
echo "Service accounts configured."

echo "Creating Redis instance..."
gcloud redis instances create $NAME \
  --region=$REGION \
  --zone=$REGION-a \
  --alternative-zone=$REGION-b \
  --tier=standard \
  --size=1 \
  --network=$NETWORK_LINK \
  --connect-mode=private-service-access \
  --redis-version=redis_7_2 \
  --enable-auth \
  --transit-encryption-mode=disabled \
  --redis-config=activedefrag=yes,maxmemory-gb=0.8 \
  --async
echo "Redis instance will continue to deploy in the background..."

echo "Creating PostgreSQL users and databases..."
gcloud sql databases create $DB_ASSISTANT_DATABASE --instance=$NAME
gcloud sql users create $DB_ASSISTANT_USERNAME --instance=$NAME --password=$DB_ASSISTANT_PASSWORD

gcloud sql databases create $DB_STUDIO_DATABASE --instance=$NAME
gcloud sql users create $DB_STUDIO_USERNAME --instance=$NAME --password=$DB_STUDIO_PASSWORD

gcloud sql databases create $DB_KEYCLOAK_DATABASE --instance=$NAME
gcloud sql users create $DB_KEYCLOAK_USERNAME --instance=$NAME --password=$DB_KEYCLOAK_PASSWORD
echo "PostgreSQL users and databases created."

echo "Infrastructure deployed successfully!"