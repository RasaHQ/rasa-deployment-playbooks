# Environment variables for GCP deployment

# You must change the following variables to match your environment
#--------------------------------
# Change this to your GCP project ID.
export PROJECT_ID=your-gcp-project-id
# Change this to the region you want to deploy to. Find the available regions here: https://cloud.google.com/about/locations
export REGION=us-central1
# Change this to the domain you want to use for your Rasa installation.
# When you complete the playbook, you will be able to access the Rasa Pro assistant at https://assistant.yourdomain.example.com
# and the Rasa Studio at https://studio.yourdomain.example.com
export DOMAIN=yourdomain.example.com
# Change this to the email address you'll use to request TLS certificates from Let's Encrypt.
export MY_EMAIL=email@example.com
# Change this to the name of your company. This will be used to generate unique bucket names.
export MY_COMPANY_NAME="rasa"
# The password you'd like to use for the Rasa Pro database.
export DB_ASSISTANT_PASSWORD="your-assistant-db-password"
# The password you'd like to use for the Rasa Studio database.
export DB_STUDIO_PASSWORD="your-studio-db-password"
# The password you'd like to use for the Keycloak database.
export DB_KEYCLOAK_PASSWORD="your-keycloak-db-password"
# The license string for Rasa Pro.
export RASA_PRO_LICENSE="Your Rasa Pro license string here"
# Your OpenAI API Key.
export OPENAI_API_KEY="Your OpenAI API Key here"
#--------------------------------

# You can optionally change the following environment variables if you have specific requirements
#--------------------------------
# A name that will be prepended to resources created by the playbook.
export NAME=rasa
# Random entropy to help generate unique bucket names and avoid collisions.
export BUCKET_NAME_ENTROPY="xbuc"
# The name of the bucket used to store models for Rasa Pro.
export MODEL_BUCKET="${MY_COMPANY_NAME}-${BUCKET_NAME_ENTROPY}-${NAME}-model"
# The name of the bucket used to store models for Rasa Studio.
export STUDIO_BUCKET="${MY_COMPANY_NAME}-${BUCKET_NAME_ENTROPY}-${NAME}-studio"
# Process your domain name to create a DNS zone name for GCP Cloud DNS.
export DNS_ZONE=$(echo "$DOMAIN" | sed -e 's/\./-/g')
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
# The version of PostgreSQL Container to use for applying some configuration to the database.
export PG_VERSION=17
# The name of the GCP service account for the Rasa Pro assistant.
export SERVICE_ACCOUNT_ASSISTANT="${NAME}-assistant@${PROJECT_ID}.iam.gserviceaccount.com"
# The name of the GCP service account for Studio.
export SERVICE_ACCOUNT_STUDIO="${NAME}-studio@${PROJECT_ID}.iam.gserviceaccount.com"
#--------------------------------


# Print the environment variables so you can see they're all set correctly.
echo "GCP Project:            $PROJECT_ID"
echo "GCP region:             $REGION"
echo "Domain:                 $DOMAIN"
echo "Let's Encrypt email:     $MY_EMAIL"
echo "Company name:           $MY_COMPANY_NAME"
echo "DB assistant password:  $DB_ASSISTANT_PASSWORD"
echo "DB studio password:     $DB_STUDIO_PASSWORD"
echo "DB keycloak password:  $DB_KEYCLOAK_PASSWORD"
echo "Rasa Pro license:       $RASA_PRO_LICENSE"
echo "OpenAI API key:         $OPENAI_API_KEY"
echo "Bucket name entropy:    $BUCKET_NAME_ENTROPY"
echo "Model bucket:           $MODEL_BUCKET"
echo "Studio bucket:          $STUDIO_BUCKET"
echo "DNS zone name:          $DNS_ZONE"
echo "Deployment name prefix: $NAME"
echo "K8S namespace:          $NAMESPACE"
echo "DB assistant database:  $DB_ASSISTANT_DATABASE"
echo "DB assistant username:  $DB_ASSISTANT_USERNAME"
echo "DB studio database:     $DB_STUDIO_DATABASE"
echo "DB studio username:     $DB_STUDIO_USERNAME"
echo "DB keycloak database:  $DB_KEYCLOAK_DATABASE"
echo "DB keycloak username:  $DB_KEYCLOAK_USERNAME"
echo "PostgreSQL version:     $PG_VERSION"
echo "Service account assistant: $SERVICE_ACCOUNT_ASSISTANT"
echo "Service account studio:    $SERVICE_ACCOUNT_STUDIO"
echo "--------------------------------"
echo "If any of the above values are incorrect or blank, please update the file and re-run.
