#!/bin/bash

cd "$(dirname "$0")"


rm g5k_image_cooking*.log

echo "Forwarding public files"
cp -r ./g5k_deploy/public/* ~/public/

echo "Submitting the image cooking job"
oarsub -S ./g5k_deploy/cook_images.sh -O g5k_image_cooking.log -E g5k_image_cooking.err.log >g5k_image_cooking.log
vim -R --cmd 'set mouse=a | syntax on | set autoread | set updatetime=100 | au CursorHold * checktime | call feedkeys("G")' g5k_image_cooking.log +
