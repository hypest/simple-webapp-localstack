# ECR is NOT included in LocalStack free tier
# Instead, we use a local Docker registry running on localhost:5000
# 
# The local registry is configured in docker-compose.dev.yml and provides
# the same functionality for development and testing purposes.
#
# For production deployments to real AWS, ECR will be configured in
# the environments/production directory.
#
# This approach allows:
# 1. Free LocalStack development without ECR limitations
# 2. Same deployment workflow between local and production
# 3. Proper container registry in production
