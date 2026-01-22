#!/bin/bash

cd ~/greenfaas
git pull > /dev/null 2>&1 || {
  git reset --hard
  git pull
  bash $0
  exit $?
}


docker run -d -p 8080:8080 openstackswift/saio
