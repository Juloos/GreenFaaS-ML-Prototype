#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$SCRIPTDIR")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH"
  exit $?
}


docker run -d -p 8080:8080 openstackswift/saio
