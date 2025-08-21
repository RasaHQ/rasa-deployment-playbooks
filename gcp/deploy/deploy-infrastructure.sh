set -e

echo "Enabling required services on GCP. This might take a few minutes..."
# GCP requires that you enable the services you wish to use in each project before you can deploy infrastructure.
# We'll attempt to enable the following services:
# - Compute Engine API (https://console.cloud.google.com/apis/library/compute.googleapis.com), for creating the virtual network.
# - Service Networking API (https://console.cloud.google.com/apis/library/servicenetworking.googleapis.com), to allow us to automatically manage networking.
# - Kubernetes Engine API (https://console.developers.google.com/apis/api/container.googleapis.com), to allow us to deploy a Google Kubernetes Engine (GKE) cluster.
# - Cloud SQL API (https://console.developers.google.com/apis/api/sqladmin.googleapis.com), to allow us to deploy a managed Cloud SQL PostgreSQL instance.
# - Google Cloud Memorystore for Redis API (https://console.developers.google.com/apis/api/redis.googleapis.com), to allow us to deploy a managed Redis instance.
# - Cloud DNS API (https://console.developers.google.com/apis/api/dns.googleapis.com), to allow us to create the required DNS records for the services.
# - IAM API (https://console.developers.google.com/apis/api/iam.googleapis.com), to allow us to manage IAM roles.
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

# Create VPC Network
# This Network Will Host:
# 1. GKE Kubernetes cluster (your Rasa application)
# 2. Cloud SQL databases (assistant, studio, keycloak)
# 3. Load balancers (for web traffic)
echo "Creating VPC network..."
gcloud compute networks create $NAME \
  --bgp-routing-mode=global \
  --subnet-mode=custom

# Create subnet
# This subnet is specifically designed for Kubernetes workloads with separate IP ranges for different types of resources.
# The private Google access feature will allow your instances to communicate with Google Cloud services even without external IP addresses.
echo "Creating subnets..."
gcloud compute networks subnets create $NAME \
  --network $NAME \
  --enable-private-ip-google-access \
  --range 10.100.80.0/24 \
  --region $REGION \
  --secondary-range pods=10.100.0.0/18 \
  --secondary-range services=10.100.64.0/20

# Configure Private Service Access
# This address range is specifically reserved for VPC peering, which allows:
# 1. Private Service Connect: Connect to Google-managed services 
# 2. Service Networking: Enable private IP connectivity to Google Cloud services
# 3. Database Connections: Allow your GKE cluster to connect privately to managed databases
# This is used when you want your Kubernetes workloads to connect to managed services like Cloud SQL databases without going through the public internet, providing better security and performance.
echo "Configuring Private Service Access..."
gcloud compute addresses create $NAME \
  --global \
  --purpose=VPC_PEERING \
  --addresses=10.100.96.0 \
  --prefix-length=19 \
  --network=$NAME

# Create the VPC peering connection to enable private connectivity to Google Cloud services.
# This VPC peering connection now allows your network to:
# 1. Connect to Cloud SQL instances with private IPs
# 2. Access other Google Cloud managed services privately
# 3. Ensure all traffic stays within Google's private network
# 4. Database connections won't go through the public internet
echo "Enabling VPC Peering..."
gcloud services vpc-peerings connect \
    --service=servicenetworking.googleapis.com \
    --ranges=$NAME \
    --network=$NAME

# Create GKE Service Account
# A service account is a special type of Google account that allows secure API access without storing credentials in code.
# In this case, it will allow the Kubernetes cluster to interact with other GCP services.
echo "Creating GCP Service Account..."
gcloud iam service-accounts create ${NAME}-gke
# Wait for 30 seconds to ensure the service account is created before trying to assign roles to it.
sleep 30

# Assign all the required permissions to this service account for things like logging or pulling container images.
# All IAM roles are now assigned to the GKE service account for Monitoring & Observability:
# 1. roles/logging.logWriter - Write logs to Cloud Logging
# 2. roles/monitoring.metricWriter - Write metrics to Cloud Monitoring
# 3. roles/cloudprofiler.agent - Send profiling data to Cloud Profiler
# 4. roles/errorreporting.writer - Write error reports to Cloud Error Reporting
# 5. roles/cloudtrace.agent - Send trace data to Cloud Trace
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

# Create GKE Cluster
# Create the Google Kubernetes Engine cluster where your Rasa Pro and Studio instances will be deployed.
# This setup provides a stable, secure Kubernetes environment with effective autoscaling and load balancing features.
# Since we've included the --async flag, this command will return immediately and the cluster creation will proceed in the background. It may take some time before the cluster is created and running.
echo "Creating GKE Cluster..."
echo "Waiting for GKE Cluster to be up before continuing. This may take a few minutes..."
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
  --workload-pool=$PROJECT_ID.svc.id.goog 

# Create DNS Service Account
# Create a service account that will let your cluster automatically create the DNS records.
echo "Creating DNS Service Account..."
gcloud iam service-accounts create $NAME-dns

# Assign the DNS Admin role to the service account to grant it the required permissions.
# This will enable automated DNS record management for your Rasa deployment, including SSL certificate automation.
echo "Assigning roles to DNS Service Account..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$NAME-dns@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/dns.admin" \
  --condition=None
  
gcloud iam service-accounts add-iam-policy-binding $NAME-dns@$PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[external-dns/external-dns]" \
  --role="roles/iam.workloadIdentityUser"

gcloud iam service-accounts add-iam-policy-binding $NAME-dns@$PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[cert-manager/cert-manager]" \
  --role="roles/iam.workloadIdentityUser"

# Create Rasa Service Accounts
# Create the service account that Rasa Pro and Rasa Studio will use to interact with GCP resources, like reading and writing models from your storage buckets.
echo "Creating Rasa Service Account and assigning roles..."
gcloud iam service-accounts create $NAME-assistant

gcloud iam service-accounts add-iam-policy-binding $NAME-assistant@$PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/assistant]" \
  --role="roles/iam.workloadIdentityUser"
echo "Rasa Service Account created and configured"

echo "Creating Rasa Studio Service Account and assigning roles..."
gcloud iam service-accounts create $NAME-studio

gcloud iam service-accounts add-iam-policy-binding $NAME-studio@$PROJECT_ID.iam.gserviceaccount.com \
  --member="serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/studio]" \
  --role="roles/iam.workloadIdentityUser"

# Create PostgreSQL instance
# Create the PostgreSQL instance that Rasa Pro and Studio will use to persist data.
# First, export the network link and PostgreSQL version environment variables.
echo "Setting up PostgreSQL instance..."
export NETWORK_LINK=$(gcloud compute networks describe $NAME --format='value(selfLink)')
export NETWORK_LINK="${NETWORK_LINK#'https://www.googleapis.com/compute/v1/'}"
echo "Network link: $NETWORK_LINK"
export PG_VERSION="17"
# Next, create the PostgreSQL instance itself. Again, we're using the --async flag to allow the command to return immediately and the instance to continue to deploy in the background.
echo "Creating PostgreSQL instance..."
echo "Waiting for PostgreSQL instance to be up before continuing. This may take a few minutes..."
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
  --maintenance-window-hour=1 

# Create Buckets
# Create the Cloud Storage buckets that Rasa Pro and Studio will use to save models.
# The storage access is now configured with the principle of least privilege, giving each service account exactly the permissions it needs for its specific bucket.
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

# Authorize Service Accounts to Bucket access
# Permit the service accounts you created earlier to use the storage buckets so models can be written and read.
# Here is how it looks:
# Rasa Assistant Service Account
#   ├── Project-wide Bucket Viewer
#   └── Full Object Admin on Model Bucket
# Rasa Studio Service Account
#   ├── Project-wide Bucket Viewer
#   └── Full Object Admin on Studio Bucket
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

# Create Redis
# Create a Redis instance that will be used as a Rasa Pro Lock Store. (https://rasa.com/docs/reference/architecture/rasa-pro#lock-store)
# The Redis instance will be created with a configuration optimized for a small, secure, and efficient caching layer.
echo "Creating Redis instance..."
echo "Waiting for Redis instance to be up before continuing. This may take a few minutes..."
gcloud redis instances create $NAME \
  --region=$REGION \
  --zone=$ZONE_1 \
  --alternative-zone=$ZONE_2 \
  --tier=standard \
  --size=1 \
  --network=$NETWORK_LINK \
  --connect-mode=private-service-access \
  --redis-version=redis_7_2 \
  --enable-auth \
  --transit-encryption-mode=disabled \
  --redis-config=activedefrag=yes,maxmemory-gb=0.8 

# Create PostgreSQL users and databases
# Create the databases and users within your PostgreSQL instance so that Rasa Pro and Studio can read and write data.
echo "Creating PostgreSQL users and databases..."
gcloud sql databases create $DB_ASSISTANT_DATABASE --instance=$NAME
gcloud sql users create $DB_ASSISTANT_USERNAME --instance=$NAME --password=$DB_ASSISTANT_PASSWORD

gcloud sql databases create $DB_STUDIO_DATABASE --instance=$NAME
gcloud sql users create $DB_STUDIO_USERNAME --instance=$NAME --password=$DB_STUDIO_PASSWORD

gcloud sql databases create $DB_KEYCLOAK_DATABASE --instance=$NAME
echo "PostgreSQL users and databases created."

echo "Infrastructure deployed! Check the output above for any errors."