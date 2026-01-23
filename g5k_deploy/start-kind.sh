#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under
#     https://github.com/apache/openwhisk-deploy-kube?tab=Apache-2.0-1-ov-file
#


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH"
  exit $?
}


set -x

SCRIPTDIR=$(cd $(dirname "$0") && pwd)

TRAVIS_KUBE_VERSION=${TRAVIS_KUBE_VERSION:="v1.20"}

# Map from Kubernetes major versions to the kind node image tag
case $TRAVIS_KUBE_VERSION in
    v1.19) KIND_NODE_TAG=v1.19.11@sha256:07db187ae84b4b7de440a73886f008cf903fcf5764ba8106a9fd5243d6f32729 ;;
    v1.20) KIND_NODE_TAG=v1.20.7@sha256:cbeaf907fc78ac97ce7b625e4bf0de16e3ea725daf6b04f930bd14c67c671ff9  ;;
    v1.21) KIND_NODE_TAG=v1.21.1@sha256:69860bda5563ac81e3c0057d654b5253219618a22ec3a346306239bba8cfa1a6  ;;
    *) echo "Unsupported Kubernetes version $TRAVIS_KUBE_VERSION"; exit 1 ;;
esac

# Boot cluster
kind create cluster --config "$SCRIPTDIR/kind-cluster.yml" --name kind --image kindest/node:${KIND_NODE_TAG} --wait 10m || exit 1

echo "Kubernetes cluster is deployed and reachable"
kubectl describe nodes
