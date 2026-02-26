#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" "$@"
  exit $?
}


rm ~/public/openwhisk_kube_*.tar.zst ~/public/docker_swift_*.tar.zst >/dev/null 2>&1
rm g5k_image_cooking*.log >/dev/null 2>&1

cp -r --remove-destination ./g5k_deploy/public/* ~/public/
for config_file in $(basename -a ./g5k_deploy/public/*.yml); do
  sed "s/{{USER}}/$USER/g" -i ~/public/$config_file
done

oarsub -S ./g5k_deploy/cook_images.sh -O g5k_image_cooking.log -E g5k_image_cooking.err.log >g5k_image_cooking.log
