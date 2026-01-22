#!/bin/sh

cd ~

helm uninstall owdev -n openwhisk
kind delete cluster --name kind
./ow_g5k/g5k_deploy/start-kind.sh &&
    helm install owdev openwhisk/openwhisk -n openwhisk --create-namespace -f openwhisk_config.yml && 
    kubectl get pods -n openwhisk --watch | grep --color=always -E "^owdev-install-packages-.*$|$"
