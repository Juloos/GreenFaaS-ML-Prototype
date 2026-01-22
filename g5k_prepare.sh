#!/bin/bash

cd "$(dirname "$0")"


echo "Forwarding public files"
cp -r ./g5k_deploy/public/* ~/public/ | sed 's/^/  /'

echo "Submitting the image cooking job..."
oarsub -S ./g5k_deploy/cook_images.sh -O g5k_image_cooking.log -E g5k_image_cooking.log | sed 's/^/  /'
watch -c -t -n 0.1 cat g5k_image_cooking.log
