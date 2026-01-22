#!/bin/bash

#OAR -t deploy
#OAR -l host=1,walltime=2:00:00
#OAR -p wattmeter=YES


cd "$(dirname "$0")"
alias prepend='sed "s/^/  /"'


HOST=`oarprint host | cut -d '.' -f 1 | head -n 1`


echo "Deploying on $HOST"
kadeploy3 -m $HOST ubuntu2004-min | prepend


echo "Installing Docker"
ssh root@$HOST <<-'EOF' | prepend
  echo "Updating system and installing dependencies"
  apt update -y | prepend
  apt upgrade -y | prepend
  apt remove -y $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1) | prepend
  apt update -y | prepend
  apt install -y ca-certificates curl | prepend

  echo "Setting up Docker repository"
  install -m 0755 -d /etc/apt/keyrings | prepend
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc | prepend
  chmod a+r /etc/apt/keyrings/docker.asc | prepend
  tee /etc/apt/sources.list.d/docker.sources <<-'EOF2' | prepend
    Types: deb
    URIs: https://download.docker.com/linux/ubuntu
    Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    Components: stable
    Signed-By: /etc/apt/keyrings/docker.asc
  EOF2

  echo "Installing Docker Engine"
  apt update -y && apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin | prepend
  apt autoremove -y | prepend
  apt clean | prepend
EOF


echo "Preparing Swift environment"
ssh root@$HOST "docker pull openstackswift/saio" | prepend
g5k-tgz -m $HOST -f ~/public/docker_swift_$(ssh root@$HOST "uname -m").tar.zst | prepend
ssh root@$HOST "docker system prune -af" | prepend


echo "Preparing OpenWhisk environment"
ssh root@$HOST <<-'EOF' | prepend
  echo "Installing dependencies"
  apt install -y apt-transport-https gnupg gpg git | prepend
  
  echo "Installing Kind v0.11.1"
  [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64 | prepend
  [ $(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-arm64 | prepend
  chmod +x ./kind | prepend
  mv ./kind /usr/bin/kind | prepend

  echo "Installing Kubernetes v1.31.14"
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31.14/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
  chmod 644 /etc/apt/sources.list.d/kubernetes.list | prepend
  apt update -y | prepend
  apt install -y kubeadm=1.31.14-00 kubectl=1.31.14-00 kubelet=1.31.14-00 | prepend
  
  echo "Installing Helm v3.19.2"
  curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null | prepend
  echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list | prepend
  apt update -y | prepend
  apt install -y helm=3.19.2-1 | prepend

  echo "Cloning the git repo"
  git clone $(git config --get remote.origin.url) --branch $(git branch --show-current) 'ow_g5k' | prepend

  echo "Cleaning up"
  apt autoremove -y | prepend
  apt clean | prepend
EOF
g5k-tgz -m $HOST -f ~/public/openwhisk_kube_$(ssh root@$HOST "uname -m").tar.zst | prepend
