# Simple Counter App with Rails, AWS, and LocalStack

A Rails web application that implements a simple counter and sends count updates to other app instances via AWS SQS, all running in a LocalStack development environment within devcontainers.

## 🏗️ Project Structure

```
simple-app-localstack/
├── .devcontainer/           # VS Code devcontainer configuration
│   └── devcontainer.json    # Container setup with Rails, AWS CLI, Terraform
├── app/                     # Rails application
│   ├── Gemfile             # Ruby dependencies
│   ├── config/             # Rails configuration
│   └── ...                 # Standard Rails structure
├── infrastructure/          # Terraform configuration
│   ├── main.tf             # Provider and LocalStack configuration
│   ├── sqs.tf              # SQS queue definitions
│   └── outputs.tf          # Terraform outputs
├── scripts/                # Setup and utility scripts
│   └── setup.sh            # Development environment setup
├── docker-compose.dev.yml  # Development services (LocalStack, Redis, Rails)
├── Dockerfile.dev          # Development container for Rails
└── README.md               # This file
```

## 🚀 Getting Started

### Prerequisites

- Docker and Docker Compose
- VS Code with the following extensions:
  - Dev Containers extension
  - AWS Toolkit
  - LocalStack Toolkit

### Setup

1. **Open in VS Code**: Open this project in VS Code
2. **Reopen in Container**: When prompted, click "Reopen in Container" or use the Command Palette (`Cmd+Shift+P`) and select "Dev Containers: Reopen in Container"
3. **Wait for Setup**: The devcontainer will automatically:
   - Build the development environment
   - Install all dependencies
   - Set up LocalStack infrastructure
   - Configure the Rails application

### Development Workflow

Once the devcontainer is running:

1. **Start the Rails server**:

   ```bash
   cd /workspace/app
   rails server
   ```

2. **Access the application**: http://localhost:3000

3. **Access LocalStack**: http://localhost:4566

4. **Monitor SQS queues**:
   ```bash
   aws --endpoint-url=http://localstack:4566 sqs list-queues
   ```

## 🏢 Architecture

### Services

- **Rails App**: Main web application with counter functionality
- **LocalStack**: Local AWS services emulation (SQS)
- **Redis**: Session store and Sidekiq backend
- **Sidekiq**: Background job processing

### AWS Resources (via LocalStack)

- **SQS Queue**: `counter-queue` for inter-app communication
- **SQS DLQ**: `counter-queue-dlq` for failed messages

## 🔧 Configuration

### Environment Variables

The devcontainer automatically sets up these environment variables:

```bash
AWS_DEFAULT_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
LOCALSTACK_ENDPOINT=http://localstack:4566
COUNTER_QUEUE_URL=http://localstack:4566/000000000000/counter-queue
REDIS_URL=redis://redis:6379/0
```

### Terraform Configuration

Infrastructure is defined in the `infrastructure/` directory:

- LocalStack provider configuration
- SQS queue and DLQ creation
- Outputs for queue URLs

## 📝 Next Steps

After setting up the basic structure, you'll want to:

1. **Generate Rails components**:

   ```bash
   rails generate controller Counter index
   rails generate model CounterEvent count:integer message:text
   ```

2. **Implement the counter logic**:

   - Counter controller with increment/decrement actions
   - SQS message publishing
   - Background job for message processing

3. **Add views and styling**:
   - Counter display
   - Action buttons
   - Real-time updates (via ActionCable or polling)

## 🛠️ Useful Commands

### Rails

```bash
rails server                    # Start the Rails server
rails console                   # Rails console
rails generate --help           # See available generators
rails db:migrate                # Run database migrations
```

### Terraform

```bash
cd infrastructure
terraform plan                  # Preview changes
terraform apply                 # Apply changes
terraform destroy               # Destroy infrastructure
```

### AWS CLI (LocalStack)

```bash
# List SQS queues
aws --endpoint-url=http://localstack:4566 sqs list-queues

# Send a test message
aws --endpoint-url=http://localstack:4566 sqs send-message \
  --queue-url http://localstack:4566/000000000000/counter-queue \
  --message-body "Test message"

# Receive messages
aws --endpoint-url=http://localstack:4566 sqs receive-message \
  --queue-url http://localstack:4566/000000000000/counter-queue
```

### Docker

```bash
docker-compose -f docker-compose.dev.yml logs localstack  # LocalStack logs
docker-compose -f docker-compose.dev.yml logs sidekiq     # Sidekiq logs

## 🧰 Devcontainer image and developer tooling

This repository now builds the devcontainer from a Dockerfile (`.devcontainer/Dockerfile`) so we can bake developer tools into the image.

- Tools installed in the devcontainer image:
   - `redis-cli` (provided by `redis-tools`) — quick Redis checks and troubleshooting
   - `jq` — JSON CLI processor
   - `http` (HTTPie) — friendlier HTTP client than curl for quick API calls

### Rebuild the devcontainer

After pulling the repo changes you'll need to rebuild the devcontainer so the new Dockerfile is used. In VS Code:

1. Open the Command Palette (Ctrl/Cmd+Shift+P)
2. Select `Dev Containers: Rebuild and Reopen in Container`

Or using the Dev Container CLI:

```bash
npm i -g @devcontainers/cli
devcontainer build --workspace-folder . --file .devcontainer/Dockerfile
devcontainer up --workspace-folder .
```

### Quick checks inside the devcontainer

```bash
which redis-cli jq http
redis-cli PING      # should return PONG if Redis is reachable
http --version
```

### Supporting services

Use the helper script to start local supporting services (Redis and a local Docker registry):

```bash
./scripts/start-supporting-services.sh
```

If you need to stop/remove them:

```bash
docker rm -f redis registry || true
```

```

## 🐛 Troubleshooting

### LocalStack not responding

```bash
# Check LocalStack health
curl http://localhost:4566/health

# Restart LocalStack
docker-compose -f docker-compose.dev.yml restart localstack
```

### Rails server issues

```bash
# Check if gems are installed
bundle check

# Reinstall gems
bundle install

# Check database
rails db:create db:migrate
```

### Port conflicts

- Rails: 3000
- LocalStack: 4566
- Redis: 6379

Make sure these ports are available on your host machine.

## 📚 Technologies Used

- **Ruby on Rails 7.0**: Web framework
- **LocalStack**: Local AWS development
- **Terraform**: Infrastructure as Code
- **Docker**: Containerization
- **Sidekiq**: Background job processing
- **Redis**: In-memory data store
- **AWS SDK**: AWS service integration
- **SQLite**: Development database
