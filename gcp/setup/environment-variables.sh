# Environment variables for GCP deployment

# You should change the following variables to match your environment
#--------------------------------
# Change this to your GCP project ID.
export PROJECT_ID=my-rasa-project-123
# Change this to the region you want to deploy to. Find the available regions here: https://cloud.google.com/about/locations
export REGION=us-central1
# Change this to the domain you want to use for your Rasa installation.
export DOMAIN=rasa.example.com
# Change this to the email address you'll use to request TLS certificates from Let's Encrypt.
export MY_EMAIL=changeme@$DOMAIN
# Change this to the name of your company. This will be used to generate unique bucket names.
export MY_COMPANY_NAME="example-company"
# The password you'd like to use for the Rasa Pro database.
export DB_ASSISTANT_PASSWORD="changeme"
# The password you'd like to use for the Rasa Studio database.
export DB_STUDIO_PASSWORD="changeme"
# The password you'd like to use for the Keycloak database.
export DB_KEYCLOAK_PASSWORD="changeme"
#--------------------------------

# You can optionally change the following environment variables if you have specific requirements
#--------------------------------
# Random entropy to help generate unique bucket names and avoid collisions.
export BUCKET_NAME_ENTROPY="xbuc"
# The name of the bucket used to store models for Rasa Pro.
export MODEL_BUCKET="${MY_COMPANY_NAME}-${BUCKET_NAME_ENTROPY}-${NAME}-model"
# The name of the bucket used to store models for Rasa Studio.
export STUDIO_BUCKET="${MY_COMPANY_NAME}-${BUCKET_NAME_ENTROPY}-${NAME}-studio"
# Process your domain name to create a DNS zone name for GCP Cloud DNS.
export DNS_ZONE=$(echo "$DOMAIN" | sed -e 's/\./-/g')
# A name that will be prepended to resources created by the playbook.
export NAME=rasa
# The Kubernetes namespace that will be used for the deployment.
export NAMESPACE=rasa
# The database name for Rasa Pro.
export DB_ASSISTANT_DATABASE="assistant"
# The username for the Rasa Pro database.
export DB_ASSISTANT_USERNAME="assistant"
# The database name for Rasa Studio.
export DB_STUDIO_DATABASE="studio"
# The username for the Rasa Studio database.
export DB_STUDIO_USERNAME="studio"
# The database name for Keycloak.
export DB_KEYCLOAK_DATABASE="keycloak"
# The username for the Keycloak database.
export DB_KEYCLOAK_USERNAME="keycloak"
#--------------------------------


# Print the environment variables so you can see they're all set correctly.
echo "GCP Project:            $PROJECT_ID"
echo "GCP region:             $REGION"
echo "ACME account email:     $MY_EMAIL"
echo "Installation name:      $NAME"
echo "K8S namespace:          $NAMESPACE"
echo "Domain:                 $DOMAIN"
echo "DNS zone name:          $DNS_ZONE"
echo "DB assistant database:  $DB_ASSISTANT_DATABASE"
echo "DB assistant username:  $DB_ASSISTANT_USERNAME"
echo "DB studio database:     $DB_STUDIO_DATABASE"
echo "DB studio username:     $DB_STUDIO_USERNAME"
echo "DB keycloak database:  $DB_KEYCLOAK_DATABASE"
echo "DB keycloak username:  $DB_KEYCLOAK_USERNAME"
echo "Model bucket:           $MODEL_BUCKET"
echo "Studio bucket:          $STUDIO_BUCKET"
