#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
git submodule update --init --recursive
cd openwhisk

#############################################################
# Full Ansible OpenWhisk install and deployment, thx chatgpt
#############################################################

OPENWHISK_HOME="$(pwd)"
ENVIRONMENT="local"
ENV_DIR="$(realpath "$OPENWHISK_HOME/ansible/environments/$ENVIRONMENT")"
CONFIG_ROOT_DIR="$ENV_DIR/config"
ANSIBLE_DIR="ansible"
ANSIBLE_PLAYBOOKS=("setup.yml" "couchdb.yml" "initdb.yml" "wipe.yml" "openwhisk.yml" "postdeploy.yml" "apigateway.yml" "routemgmt.yml")
VENV_DIR="/opt/openwhisk-venv"
GRADLE_VERSION="6.9.1"
GRADLE_DIR="/opt/gradle/gradle-${GRADLE_VERSION}"
GRADLEW="./gradlew"

export ANSIBLE_HOST_KEY_CHECKING=False
export OPENWHISK_ENVIRONMENT="$ENVIRONMENT"
export env_hosts_dir=$(realpath "$ENV_DIR")
export config_root_dir=$(realpath "$CONFIG_ROOT_DIR")
export DOCKER_HOST="unix:///var/run/docker.sock"

#############################################
# Sanity checks
#############################################

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Must be run as root"
    exit 1
fi

if [[ ! -d "$OPENWHISK_HOME/ansible" ]]; then
    echo "ERROR: Run this from the OpenWhisk repo root"
    exit 1
fi

#############################################
# System preparation
#############################################

apt update -y
apt upgrade -y
apt install -y \
  ca-certificates curl gnupg lsb-release software-properties-common \
  git unzip tar jq build-essential python3 python3-venv python3-pip \
  openjdk-11-jdk wget unzip npm

#############################################
# Docker installation (skip if compatible)
#############################################

docker_installed_and_working() {
    if command -v docker >/dev/null 2>&1 && command -v containerd >/dev/null 2>&1; then
        DOCKER_VER=$(docker --version 2>/dev/null | awk '{print $3}' | sed 's/,//')
        [[ -n "$DOCKER_VER" ]] && return 0
    fi
    return 1
}

if docker_installed_and_working; then
    echo "Docker and containerd already installed and working — skipping installation."
else
    echo "Installing Docker CE..."
    apt remove -y docker.io docker docker-engine docker-ce docker-ce-cli containerd runc || true
    apt autoremove -y || true

    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt update -y
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl enable docker
    systemctl start docker

    mkdir -p /etc/docker
    cat >/etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": { "max-size": "100m" },
  "storage-driver": "overlay2"
}
EOF
    systemctl restart docker
fi

#############################################
# Install Gradle
#############################################

if [[ ! -d "$GRADLE_DIR" ]]; then
    echo "Installing Gradle $GRADLE_VERSION..."
    wget https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -P /tmp
    unzip -d /opt/gradle /tmp/gradle-${GRADLE_VERSION}-bin.zip
fi
export PATH="$GRADLE_DIR/bin:$PATH"

#############################################
# Remove old OpenWhisk containers
#############################################
echo "Cleaning up existing OpenWhisk containers..."
docker ps -a --filter "name=^/whisk_" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "name=^/kafka" --format "{{.ID}}" | xargs -r docker rm -f || true
docker ps -a --filter "name=^/couchdb" --format "{{.ID}}" | xargs -r docker rm -f || true

#############################################
# Build OpenWhisk Docker images
#############################################

echo "Building OpenWhisk Docker images..."
$GRADLEW distDocker -PuseMavenCentral=true

#############################################
# Python virtualenv for Ansible
#############################################

apt install -y ansible

if [[ ! -d "$VENV_DIR" ]]; then
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip

# Downgrade requests to avoid docker-py http+docker error
pip install "docker>=5.0.3" "jinja2" "requests<2.32" "passlib" "netaddr"

export ANSIBLE_PYTHON_INTERPRETER="$VENV_DIR/bin/python"

#############################################
# Ansible Galaxy roles
#############################################

if [[ -f ansible/requirements.yml ]]; then
    ansible-galaxy install -r ansible/requirements.yml
fi

#############################################
# Inventory bootstrap
#############################################

mkdir -p "$ENV_DIR/group_vars"
mkdir -p "$config_root_dir/nginx"

if [[ ! -f "$ENV_DIR/hosts" ]]; then
    cat >"$ENV_DIR/hosts" <<EOF
[edge]
localhost ansible_connection=local

[controllers]
localhost ansible_connection=local

[kafkas]
localhost ansible_connection=local

[zookeepers]
localhost ansible_connection=local

[invokers]
localhost ansible_connection=local

[couchdbs]
localhost ansible_connection=local

[redis]
localhost ansible_connection=local

[db]
localhost ansible_connection=local

[whisk:children]
controllers
invokers
edge
EOF
fi

#############################################
# Single-node tuning + DB prefix
#############################################

cat >"$ENV_DIR/group_vars/all" <<EOF
invoker_count: 8
invoker_container_memory: 2560m
invoker_container_cpu: 2
invoker_numcore: 2

limits:
  actions:
    memory:
      default: 256m
      max: 1024m

controller_heap_size: 1024m
invoker_heap_size: 1024m

db_prefix: whisk_local

# Nginx SSL
nginx_ssl_server_cert: openwhisk-server-cert.pem
nginx_ssl_server_key: openwhisk-server-key.pem
nginx_ssl_client_ca_cert: openwhisk-client-ca-cert.pem
nginx_ssl_verify_client: off

# Ansible Docker
docker_host: "unix:///var/run/docker.sock"
docker_python_module: "docker"

env_hosts_dir: "$ENV_DIR"
inventory_dir: "$ENV_DIR"
config_root_dir: "$config_root_dir"
EOF

#############################################
# Clean previous certificates
#############################################

rm -f "$config_root_dir/nginx/openwhisk-server-cert.pem" \
      "$config_root_dir/nginx/openwhisk-server-key.pem"

#############################################
# Deploy OpenWhisk with Ansible
#############################################

echo "Starting OpenWhisk deployment..."

mkdir -p "$OPENWHISK_HOME/environments/$ENVIRONMENT"

# Kafka certs directory
KAFKA_CERTS_DIR="$CONFIG_ROOT_DIR/kafka/certs"
mkdir -p "$KAFKA_CERTS_DIR"
export KAFKA_CERTS_DIR

pushd "$ANSIBLE_DIR" >/dev/null

# Generate host file if missing
[ ! -f "$ENV_DIR/hosts" ] && echo "localhost" > "$ENV_DIR/hosts"

# Patch docker login task to be conditional
sed -i \
'/name: docker login/,/when:/{
  /when:/c\
when:\
  - docker_registry is defined\
  - docker_registry != ""\
  - docker_registry_password is defined
}' \
tasks/docker_login.yml

ansible-playbook -i "environments/${ENVIRONMENT}" ${ANSIBLE_PLAYBOOKS[@]} \
  --extra-vars "config_root_dir=$config_root_dir env_hosts_dir=$ENV_DIR inventory_dir=$ENV_DIR docker_host=unix:///var/run/docker.sock docker_python_module=docker kafka_certs_dir=$KAFKA_CERTS_DIR" -v

popd >/dev/null

#############################################
# Post-install summary
#############################################

echo
echo "========================================="
echo "OpenWhisk deployment completed"
echo
echo "Invoker count:        8"
echo "Invoker memory:      2560 MB"
echo "Invoker CPU:         2 cores"
echo "Max action memory:   1024 MB"
echo
echo "Controller endpoint:"
echo "  https://localhost"
echo
echo "Auth file:"
echo "  ansible/files/auth.whisk.system"
echo "========================================="
