#!/bin/bash


cd "$(dirname "$0")"
git pull > /dev/null 2>&1 || {
  git reset --hard
  git pull
  bash $0
  exit $?
}


rm ~/public/openwhisk_kube_*.tar.zst ~/public/docker_swift_*.tar.zst
rm g5k_image_cooking*.log

cp -r ./g5k_deploy/public/* ~/public/
for config_file in $(basename -a ./g5k_deploy/public/*.yml); do
  sed "s/{{USER}}/$USER/g" -i ~/public/$config_file
done

oarsub -S ./g5k_deploy/cook_images.sh -O g5k_image_cooking.log -E g5k_image_cooking.err.log >g5k_image_cooking.log
view g5k_image_cooking.log
