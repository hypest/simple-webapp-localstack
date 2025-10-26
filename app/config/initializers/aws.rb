# Configure AWS SDK for LocalStack
require 'aws-sdk-sqs'

Aws.config.update(
  region: ENV.fetch('AWS_DEFAULT_REGION', 'us-east-1'),
  access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID', 'test'),
  secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY', 'test')
)

# Configure SQS client with LocalStack endpoint
SQS_CLIENT = Aws::SQS::Client.new(
  endpoint: ENV.fetch('LOCALSTACK_ENDPOINT', 'http://localstack:4566'),
  region: ENV.fetch('AWS_DEFAULT_REGION', 'us-east-1')
)

# Queue URLs
COUNTER_QUEUE_URL = ENV.fetch('COUNTER_QUEUE_URL', 'http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/counter-queue')