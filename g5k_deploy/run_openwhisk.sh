#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" "$@"
  exit $?
}


cd ~

totalKB=$(awk '/MemTotal:/{print $2}' /proc/meminfo)
cp ./greenfaas/g5k_deploy/openwhisk_config.yml .
sed "s/{{USER_MEM_GB}}/$(( $totalKB * 80 / 100 / 1000000 ))/g" -i ./openwhisk_config
sed "s/{{INVOKER_MEM_MB}}/$(( $totalKB * 10 / 100 / 1000 ))/g" -i ./openwhisk_config

helm uninstall owdev -n openwhisk
kind delete cluster --name kind

swapoff -a
./greenfaas/g5k_deploy/start-kind.sh &&
  helm install owdev openwhisk/openwhisk -n openwhisk --create-namespace -f ./openwhisk_config.yml && {
    while true; do
      kubectl get pods -n openwhisk --watch | grep --color=always -E "^owdev-install-packages-.*$|$"
    done
  }
