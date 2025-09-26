# Environment variables for AWS deployment

# You must change the following variables to match your environment
#--------------------------------
# Set the value of this to terraform if you've chosen to use Terraform for deployment or tofu if you've chosen to use OpenTofu for deployment.
export TF_CMD=terraform
# Change this to the name of the AWS profile you want to use which you have configured in your ~/.aws/config file.
export AWS_PROFILE=your-aws-profile-name
# Change this to the AWS region you want to deploy to. Find the available regions here: https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html
export AWS_REGION=us-east-1
export REGION=$AWS_REGION
# Change this to the domain you want to use for your Rasa installation.
# When you complete the playbook, you will be able to access the Rasa Pro assistant at https://assistant.yourdomain.example.com
# and the Rasa Studio at https://studio.yourdomain.example.com
export DOMAIN=yourdomain.example.com
# Change this to the email address you'll use to request TLS certificates from Let's Encrypt.
export MY_EMAIL=email@example.com
# Change this to the name of your company. This will be used to generate unique bucket names.
export MY_COMPANY_NAME="rasa"
# The password you'd like to use for the Rasa Studio database.
export DB_STUDIO_PASSWORD="your-studio-db-password"
# The license string for Rasa Pro.
export RASA_PRO_LICENSE="Your Rasa Pro license string here"
# Your OpenAI API Key.
export OPENAI_API_KEY="Your OpenAI API Key here"
# The name of the model to be uploaded to the model bucket as an initial model.
export MODEL_PATH="model.tar.gz"
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
# Process your domain name to create a DNS zone name for Amazon Route 53.
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
# The version of PostgreSQL Container to use for applying some configuration to the database.
export PG_VERSION=17
# The username for the ElastiCache Redis IAM role.
export REDIS_USER="${NAME}-redis-user"
#--------------------------------

# You almost certainly don't need to change the following environment variables which define the network architecture of the deployment.
# Only change them if you have specific requirements.
# These won't be printed out when you run the script.
#--------------------------------
export CIDR_ALL=10.100.0.0/17

export CIDR_PUBLIC_A=10.100.4.0/22
export CIDR_PRIVATE_A=10.100.8.0/21
export CIDR_DB_A=10.100.16.0/21
export CIDR_ELASTICACHE_A=10.100.24.0/21
export CIDR_MSK_A=10.100.96.0/21

export CIDR_PUBLIC_B=10.100.36.0/22
export CIDR_PRIVATE_B=10.100.40.0/21
export CIDR_DB_B=10.100.48.0/21
export CIDR_ELASTICACHE_B=10.100.56.0/21
export CIDR_MSK_B=10.100.104.0/21

export CIDR_PUBLIC_C=10.100.68.0/22
export CIDR_PRIVATE_C=10.100.72.0/21
export CIDR_DB_C=10.100.80.0/21
export CIDR_ELASTICACHE_C=10.100.88.0/21
export CIDR_MSK_C=10.100.112.0/21
#--------------------------------

# Print the environment variables so you can see they're all set correctly.
echo "AWS Profile:            $AWS_PROFILE"
echo "AWS Region:             $AWS_REGION"
echo "Domain:                 $DOMAIN"
echo "Let's Encrypt email:    $MY_EMAIL"
echo "Company name:           $MY_COMPANY_NAME"
echo "DB studio password:     $DB_STUDIO_PASSWORD"
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
echo "DB keycloak database:   $DB_KEYCLOAK_DATABASE"
echo "Redis user:             $REDIS_USER"
echo "PostgreSQL version:     $PG_VERSION"
echo "--------------------------------"
echo "If any of the above values are incorrect or blank, please update the file and re-run."
