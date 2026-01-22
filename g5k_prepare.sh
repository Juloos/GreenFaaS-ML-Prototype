#!/bin/bash

cd "$(dirname "$0")"


rm g5k_image_cooking*.log

echo "Forwarding public files"
cp -r ./g5k_deploy/public/* ~/public/

echo "Submitting the image cooking job"
oarsub -S ./g5k_deploy/cook_images.sh -O g5k_image_cooking.log -E g5k_image_cooking.err.log >g5k_image_cooking.log
watch -c -t -n 1 'cat g5k_image_cooking.log | tail -32'
