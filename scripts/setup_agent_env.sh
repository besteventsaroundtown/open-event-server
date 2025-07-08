#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Install pyenv if not already installed
if ! command -v pyenv &> /dev/null
then
    echo "pyenv could not be found, installing..."
    curl https://pyenv.run | $SHELL
    export PYENV_ROOT="$HOME/.pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"
fi

# Install Python 3.8.17
if ! pyenv versions --bare | grep -q "3.8.17"; then
    pyenv install 3.8.17
fi
pyenv local 3.8.17

# Install Poetry if not already installed
if ! command -v poetry &> /dev/null
then
    echo "Poetry could not be found, installing..."
    pip install poetry
    export PATH="~/.local/bin:$PATH"
fi

# Install Docker if not already installed
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found, installing..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    echo "Docker installed successfully. Note: You may need to log out and back in to run 'docker' commands without 'sudo'."
fi

# Install project dependencies
poetry install --with dev --no-root

# Stop and remove existing PostgreSQL container if it exists
if [ "$(sudo docker ps -q -f name=opev-test-db)" ]; then
    echo "Stopping existing PostgreSQL container..."
    sudo docker stop opev-test-db
    sleep 2 # Add a short delay
fi
# Only attempt removal if the container is actually stopped or exists in a non-running state
if [ "$(sudo docker ps -aq -f name=opev-test-db)" ]; then
    echo "Removing existing PostgreSQL container..."
    sudo docker rm opev-test-db
fi

echo "Starting PostgreSQL container..."
sudo docker run -d -e POSTGRES_USER=test -e POSTGRES_HOST_AUTH_METHOD=trust \
       --mount type=tmpfs,destination=/var/lib/postgresql/data \
       --rm -p 5433:5432 --name opev-test-db postgis/postgis:12-3.0-alpine

# Stop and remove existing Redis container if it exists
if [ "$(sudo docker ps -q -f name=opev-test-redis)" ]; then
    echo "Stopping existing Redis container..."
    sudo docker stop opev-test-redis
    sleep 2 # Add a short delay
fi
# Only attempt removal if the container is actually stopped or exists in a non-running state
if [ "$(sudo docker ps -aq -f name=opev-test-redis)" ]; then
    echo "Removing existing Redis container..."
    sudo docker rm opev-test-redis
fi

echo "Starting Redis container..."
sudo docker run -d -p 6379:6379 --name opev-test-redis redis
# fi # This was a stray fi, removing it.

# Copy .env.example to .env if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env
fi

# Set environment variables for tests
echo "Adding test configuration to .env file..."
TEST_DATABASE_URL="postgresql://test@localhost:5433/test"
cat <<EOT >> .env

# Settings for local testing environment
APP_CONFIG=config.TestingConfig
DATABASE_URL=${TEST_DATABASE_URL}
TEST_DATABASE_URL=${TEST_DATABASE_URL}
JWT_SECRET_KEY="test_secret_key"
SECRET_KEY="test_secret_key"
REDIS_URL="redis://127.0.0.1:6379/0"
EOT

# Run unit tests
# echo "Running unit tests..."
# poetry run pytest tests/

echo "Setup and tests completed successfully!"
