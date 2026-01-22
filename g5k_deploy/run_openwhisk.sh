#!/bin/bash

cd ~/greenfaas
git pull > /dev/null 2>&1 || {
  git reset --hard
  git pull
  bash $0
  exit $?
}


cd ~

helm uninstall owdev -n openwhisk
kind delete cluster --name kind

./greenfaas/g5k_deploy/start-kind.sh &&
  helm install owdev openwhisk/openwhisk -n openwhisk --create-namespace -f ./greenfaas/g5k_deploy/openwhisk_config.yml && 
  kubectl get pods -n openwhisk --watch | grep --color=always -E "^owdev-install-packages-.*$|$"
