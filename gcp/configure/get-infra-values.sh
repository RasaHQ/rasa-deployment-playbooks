echo "Fetching some infrastructure values..."
export DB_HOST=$(gcloud sql instances describe $NAME --format='value(ipAddresses[0].ipAddress)')
export REDIS_HOST=$(gcloud redis instances describe $NAME --region=$REGION --format='value(host)')
export REDIS_AUTH=$(gcloud redis instances get-auth-string $NAME --region=$REGION --format='value(authString)')
echo "Infrastructure values fetched successfully:"
echo "DB_HOST: $DB_HOST"
echo "REDIS_HOST: $REDIS_HOST"
echo "REDIS_AUTH: $REDIS_AUTH"