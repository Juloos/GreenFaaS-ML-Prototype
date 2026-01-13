#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
git submodule update --init --recursive
cd openwhisk

#############################################################
# Full Ansible OpenWhisk install and deployment, thx chatgpt
#############################################################

# ----------------------------
# Configuration
# ----------------------------
OPENWHISK_HOME=${OPENWHISK_HOME:-$(pwd)}
ENVIRONMENT=${ENVIRONMENT:-local}
ANSIBLE_DIR="$OPENWHISK_HOME/ansible"

# ----------------------------
# Ensure directories exist
# ----------------------------
mkdir -p "$OPENWHISK_HOME/environments/$ENVIRONMENT"
ENV_DIR=$(realpath "$OPENWHISK_HOME/environments/$ENVIRONMENT")
CONFIG_ROOT_DIR="$ENV_DIR/config"

# Kafka certs directory
KAFKA_CERTS_DIR="$CONFIG_ROOT_DIR/kafka/certs"
mkdir -p "$KAFKA_CERTS_DIR"
export KAFKA_CERTS_DIR

# ----------------------------
# Update system packages
# ----------------------------
apt-get update
apt-get install -y curl wget git lsb-release ca-certificates \
                   build-essential unzip tar python3-venv python3-pip \
                   openjdk-11-jdk npm locales bash sed openssl
locale-gen en_US.UTF-8

# ----------------------------
# Ensure virtualenv exists
# ----------------------------
if [ ! -d "$OPENWHISK_HOME/openwhisk-venv" ]; then
    python3 -m venv "$OPENWHISK_HOME/openwhisk-venv"
fi
source "$OPENWHISK_HOME/openwhisk-venv/bin/activate"

# Upgrade pip and downgrade requests to avoid docker-py issues
pip install --upgrade pip
pip install "requests<3.0" docker>=5.0.3 jinja2 ansible passlib netaddr

# ----------------------------
# Remove old OpenWhisk containers
# ----------------------------
echo "Cleaning up existing OpenWhisk containers..."
docker ps -a --filter "name=^/whisk_" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "name=^/kafka" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "name=^/couchdb" --format "{{.ID}}" | xargs -r docker rm -f || true

# ----------------------------
# Build OpenWhisk Docker images
# ----------------------------
pushd "$OPENWHISK_HOME" >/dev/null

echo "Building OpenWhisk Docker images..."
./gradlew distDocker

popd >/dev/null

# ----------------------------
# Deploy OpenWhisk via Ansible
# ----------------------------
echo "Starting OpenWhisk deployment..."
pushd "$ANSIBLE_DIR" >/dev/null

# Generate host file if missing
[ ! -f "$ENV_DIR/hosts" ] && echo "localhost" > "$ENV_DIR/hosts"

ansible-playbook -i "$ENV_DIR/hosts" playbooks/setup.yml \
  --extra-vars "config_root_dir=$CONFIG_ROOT_DIR \
                env_hosts_dir=$ENV_DIR \
                inventory_dir=$ENV_DIR \
                docker_host=unix:///var/run/docker.sock \
                docker_python_module=docker \
                kafka_certs_dir=$KAFKA_CERTS_DIR" -v

popd >/dev/null

echo "OpenWhisk deployment complete!"
