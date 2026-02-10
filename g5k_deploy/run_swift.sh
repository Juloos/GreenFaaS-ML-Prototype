#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" $@
  exit $?
}


did="$(docker run -d -p 8080:8080 openstackswift/saio)"
docker exec "$did" watch -tw "cat /var/log/swift/all.log" | awk '!seen[$0]++'
