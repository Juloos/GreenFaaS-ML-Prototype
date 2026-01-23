#!/bin/bash

cd "$(dirname "$0")"
MD5=`md5sum "$0" | cut -d ' ' -f 1`
git pull
[ "$MD5" == "`md5sum \"$0\" | cut -d ' ' -f 1`" ] && {
  bash "$0"
  exit $?
}


cd ~

helm uninstall owdev -n openwhisk
kind delete cluster --name kind

./greenfaas/g5k_deploy/start-kind.sh &&
  helm install owdev openwhisk/openwhisk -n openwhisk --create-namespace -f ./greenfaas/g5k_deploy/openwhisk_config.yml && 
  kubectl get pods -n openwhisk --watch | grep --color=always -E "^owdev-install-packages-.*$|$"
