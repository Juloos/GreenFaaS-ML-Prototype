#!/bin/sh

cd "$(dirname "$0")"

git submodule update --init --recursive

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh --dry-run
