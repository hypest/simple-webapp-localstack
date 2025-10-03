# AWS SDK Configuration for LocalStack
if Rails.env.development?
  Aws.config.update(
    region: Rails.application.config.aws_region,
    credentials: Aws::Credentials.new('test', 'test'),
    endpoint: Rails.application.config.localstack_endpoint,
    force_path_style: true,
    verify_response: false
  )
end