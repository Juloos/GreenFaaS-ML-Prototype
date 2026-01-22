#!/bin/bash

cd ~/greenfaas
git pull > /dev/null 2>&1 || {
  git reset --hard
  git pull
  bash $0
  exit $?
}


cd "$(dirname "$0")"


rm ~/public/openwhisk_kube_*.tar.zst ~/public/docker_swift_*.tar.zst
rm g5k_image_cooking*.log

cp -r ./g5k_deploy/public/* ~/public/

oarsub -S ./g5k_deploy/cook_images.sh -O g5k_image_cooking.log -E g5k_image_cooking.err.log >g5k_image_cooking.log
view g5k_image_cooking.log
