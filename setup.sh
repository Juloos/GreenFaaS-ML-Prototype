#!/bin/sh

cd "$(dirname "$0")"

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh ./get-docker.sh --dry-run
