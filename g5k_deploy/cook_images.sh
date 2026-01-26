#!/bin/bash

#OAR -t deploy
#OAR -l host=1,walltime=0:30:00
#OAR -p wattmeter=YES


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" $@
  exit $?
}


HOST=`oarprint host | cut -d '.' -f 1 | head -n 1`


echo -e "\nDeploying on $HOST"
kadeploy3 -m $HOST ubuntu2004-min |& sed "s/^/  /"


echo -e "\nInstalling Docker"
ssh root@$HOST <<-"EOF" |& sed "s/^/  /"
  echo -e "\nUpdating system and installing dependencies"
  apt update -y |& sed "s/^/  /"
  apt upgrade -y |& sed "s/^/  /"
  apt remove -y $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc 2>/dev/null | cut -f1) |& sed "s/^/  /"
  apt update -y |& sed "s/^/  /"
  apt install -y ca-certificates curl |& sed "s/^/  /"

  echo -e "\nSetting up Docker repository"
  install -m 0755 -d /etc/apt/keyrings |& sed "s/^/  /"
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc |& sed "s/^/  /"
  chmod a+r /etc/apt/keyrings/docker.asc |& sed "s/^/  /"
  tee /etc/apt/sources.list.d/docker.sources <<EOF2 |& sed "s/^/  /"
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo -e "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF2

  echo -e "\nInstalling Docker Engine"
  apt update -y |& sed "s/^/  /"
  apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin |& sed "s/^/  /"
  apt autoremove -y |& sed "s/^/  /"
  apt clean |& sed "s/^/  /"

  echo -e "\nCloning the git repo"
  git clone "https://github.com/Juloos/GreenFaaS-ML-Prototype" --branch "NoML-Energy-Monitoring" "greenfaas" |& sed "s/^/  /"
  cp -r greenfaas/bin/* /usr/bin/ |& sed "s/^/  /"
EOF


echo -e "\nPreparing Swift environment"
ssh root@$HOST "docker pull openstackswift/saio" |& sed "s/^/  /"
tgz-g5k -m $HOST -f ~/public/docker_swift_$(ssh root@$HOST "uname -m").tar.zst |& sed "s/^/  /"
ssh root@$HOST "docker system prune -af" |& sed "s/^/  /"


echo -e "\nPreparing Openwhisk environment"
ssh root@$HOST <<-EOF |& sed "s/^/  /"
  echo -e "\nInstalling dependencies"
  apt install -y apt-transport-https gnupg gpg git python3-swiftclient |& sed "s/^/  /"
  
  echo -e "\nInstalling Kind v0.11.1"
  [ \$(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64 |& sed "s/^/  /"
  [ \$(uname -m) = aarch64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-arm64 |& sed "s/^/  /"
  chmod +x ./kind |& sed "s/^/  /"
  mv ./kind /usr/bin/kind |& sed "s/^/  /"

  echo -e "\nInstalling Kubernetes v1.31.14"
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg |& sed "s/^/  /"
  echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list |& sed "s/^/  /"
  chmod 644 /etc/apt/sources.list.d/kubernetes.list |& sed "s/^/  /"
  apt update -y |& sed "s/^/  /"
  apt install -y kubeadm kubectl kubelet |& sed "s/^/  /"
  
  echo -e "\nInstalling Helm v3.19.2"
  curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null |& sed "s/^/  /"
  echo -e "\ndeb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | tee /etc/apt/sources.list.d/helm-stable-debian.list |& sed "s/^/  /"
  apt update -y |& sed "s/^/  /"
  apt install -y helm=3.19.2-1 |& sed "s/^/  /"

  echo -e "\nAdding Openwhisk Helm repo"
  helm repo add openwhisk https://openwhisk.apache.org/charts |& sed "s/^/  /"
  helm repo update |& sed "s/^/  /"

  echo -e "\nCleaning up"
  apt autoremove -y |& sed "s/^/  /"
  apt clean |& sed "s/^/  /"
EOF
tgz-g5k -m $HOST -f ~/public/openwhisk_kube_$(ssh root@$HOST "uname -m").tar.zst |& sed "s/^/  /"

echo -e "\nDone."
