require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module SimpleCounterApp
  class Application < Rails::Application
    config.load_defaults 7.0

    # Configuration for the application
    config.active_job.queue_adapter = :sidekiq
    
    # AWS Configuration
    config.aws_region = ENV.fetch("AWS_DEFAULT_REGION", "us-east-1")
    config.localstack_endpoint = ENV.fetch("LOCALSTACK_ENDPOINT", "http://localhost:4566")
    
    # SQS Configuration
    config.counter_queue_url = ENV.fetch("COUNTER_QUEUE_URL", "http://localhost:4566/000000000000/counter-queue")
    
    # Allow connections from devcontainer and LocalStack
    config.hosts << "rails-dev"
    config.hosts << /.*\.localstack\.cloud/
    config.hosts << /.*\.localhost/
  end
end