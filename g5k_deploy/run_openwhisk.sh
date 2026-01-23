#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" $@
  exit $?
}


cd ~

helm uninstall owdev -n openwhisk
kind delete cluster --name kind

./greenfaas/g5k_deploy/start-kind.sh &&
  helm install owdev openwhisk/openwhisk -n openwhisk --create-namespace -f ./greenfaas/g5k_deploy/openwhisk_config.yml && 
  kubectl get pods -n openwhisk --watch | grep --color=always -E "^owdev-install-packages-.*$|$"
