# Environment variables for Azure deployment

# You must change the following variables to match your environment
#--------------------------------
# Set the value of this to terraform if you've chosen to use Terraform for deployment or tofu if you've chosen to use OpenTofu for deployment.
export TF_CMD=tofu
# Change this to your Azure tenant ID.
export ARM_TENANT_ID=your-tenant-id
# Change this to your Azure subscription ID.
export ARM_SUBSCRIPTION_ID=your-subscription-id
# Change this to the Azure region you want to deploy to. Find the available regions by running: `az account list-locations -o table`
export REGION=eastus2
# Change this to the domain you want to use for your Rasa installation.
# When you complete the playbook, you will be able to access the Rasa Pro assistant at https://assistant.yourdomain.example.com
# and the Rasa Studio at https://studio.yourdomain.example.com
export DOMAIN=yourdomain.example.com
# Change this to the email address you'll use to request TLS certificates from Let's Encrypt.
export MY_EMAIL=email@example.com
# The password you'd like to use for the Rasa Pro database.
export DB_ASSISTANT_PASSWORD="your-assistant-db-password"
# The password you'd like to use for the Rasa Studio database.
export DB_STUDIO_PASSWORD="your-studio-db-password"
# The license string for Rasa Pro.
export RASA_PRO_LICENSE="Your Rasa Pro license string here"
# Your OpenAI API Key.
export OPENAI_API_KEY="Your OpenAI API Key here"
#--------------------------------

# You can optionally change the following environment variables if you have specific requirements
#--------------------------------
# A name that will be prepended to resources created by the playbook.
export NAME=rasa
# The name of the bucket used to store models for Rasa Pro.
export ASSISTANT_STORAGE_CONTAINER="${NAME}-assistant"
# The name of the bucket used to store models for Rasa Studio.
export STUDIO_STORAGE_CONTAINER="${NAME}-studio"
# The Kubernetes namespace that will be used for the deployment.
export NAMESPACE=rasa
# The database name for Rasa Pro.
export DB_ASSISTANT_DATABASE="assistant"
# The username for the Rasa Pro database.
export DB_ASSISTANT_USERNAME="assistant"
# The database name for Rasa Studio.
export DB_STUDIO_DATABASE="studio"
# The database name for Keycloak.
export DB_KEYCLOAK_DATABASE="keycloak"
# The username for the Rasa Studio databases.
export DB_STUDIO_USERNAME="studio"
# The version of PostgreSQL Container to use for applying some configuration to the database.
export PG_VERSION=17
#--------------------------------

# You almost certainly don't need to change the following environment variables which define the network architecture of the deployment.
# Only change them if you have specific requirements.
# These won't be printed out when you run the script.
#--------------------------------
export CIDR_ALL=10.100.0.0/17

export CIDR_PODS=10.100.0.0/18
export CIDR_SERVICES=10.100.64.0/20
export CIDR_NODES=10.100.80.0/21
export CIDR_DB=10.100.96.0/21
export CIDR_REDIS=10.100.104.0/21
#--------------------------------

# Print the environment variables so you can see they're all set correctly.
echo "Azure Tenant ID:             $ARM_TENANT_ID"
echo "Azure Subscription ID:       $ARM_SUBSCRIPTION_ID"
echo "Azure Region:                $REGION"
echo "Domain:                      $DOMAIN"
echo "Let's Encrypt email:         $MY_EMAIL"
echo "DB assistant password:       $DB_ASSISTANT_PASSWORD"
echo "DB studio password:          $DB_STUDIO_PASSWORD"
echo "Rasa Pro license:            $RASA_PRO_LICENSE"
echo "OpenAI API key:              $OPENAI_API_KEY"
echo "Assistant storage container: $ASSISTANT_STORAGE_CONTAINER"
echo "Studio storage container:    $STUDIO_STORAGE_CONTAINER"
echo "Deployment name prefix:      $NAME"
echo "K8S namespace:               $NAMESPACE"
echo "DB assistant database:       $DB_ASSISTANT_DATABASE"
echo "DB assistant username:       $DB_ASSISTANT_USERNAME"
echo "DB studio database:          $DB_STUDIO_DATABASE"
echo "DB keycloak database:        $DB_KEYCLOAK_DATABASE"
echo "DB studio username:          $DB_STUDIO_USERNAME"
echo "PostgreSQL version:          $PG_VERSION"
echo "--------------------------------"
echo "If any of the above values are incorrect or blank, please update the file and re-run."
