#!/bin/bash

cd "$(dirname "$0")"


echo "Forwarding public files"
cp -r ./g5k_deploy/public/* ~/public/ |& sed 's/^/  /'

echo "Submitting the image cooking job"
rm g5k_image_cooking*.log
oarsub -S ./g5k_deploy/cook_images.sh -O g5k_image_cooking.log -E g5k_image_cooking.err.log |& sed 's/^/  /'
watch -c -n 1 cat g5k_image_cooking.log
