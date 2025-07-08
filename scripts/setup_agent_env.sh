#!/bin/bash

# Install Docker if not already installed
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found, installing..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh

    # Explicitly start the Docker daemon using the 'service' command
    # for compatibility with non-systemd environments.
    echo "Starting Docker service..."
    sudo service docker start
    # Wait a moment for the daemon to initialize.
    sleep 5

    echo "Docker installed successfully. Note: You may need to log out and back in to run 'docker' commands without 'sudo'."
fi

# Install pyenv if not already installed
if ! command -v pyenv &> /dev/null
then
    echo "pyenv could not be found, installing..."
    curl https://pyenv.run | $SHELL
    # Add pyenv configuration to shell startup file for future sessions
    if ! grep -q 'pyenv init' "$HOME/.bashrc" 2>/dev/null; then
        echo "Adding pyenv configuration to ~/.bashrc..."
        echo '' >> "$HOME/.bashrc"
        echo '# pyenv configuration' >> "$HOME/.bashrc"
        echo 'export PYENV_ROOT="$HOME/.pyenv"' >> "$HOME/.bashrc"
        echo 'export PATH="$PYENV_ROOT/bin:$PATH"' >> "$HOME/.bashrc"
        echo 'eval "$(pyenv init --path)"' >> "$HOME/.bashrc"
        echo 'eval "$(pyenv init -)"' >> "$HOME/.bashrc"
    fi
fi

# Configure pyenv for the CURRENT session
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

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
    # Add poetry to PATH in shell startup file for future sessions
    POETRY_PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
    if ! grep -q ".local/bin" "$HOME/.bashrc" 2>/dev/null; then
        echo "Adding Poetry to PATH in ~/.bashrc..."
        echo '' >> "$HOME/.bashrc"
        echo "# Add Poetry to PATH" >> "$HOME/.bashrc"
        echo "$POETRY_PATH_LINE" >> "$HOME/.bashrc"
    fi
fi

# Configure Poetry for the CURRENT session
export PATH="$HOME/.local/bin:$PATH"



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

echo "Environment setup complete. You can now run tests in this terminal or a new one"
