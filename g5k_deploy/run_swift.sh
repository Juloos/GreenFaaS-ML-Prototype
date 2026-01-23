#!/bin/bash

cd "$(dirname "$0")"
MD5=`md5sum "$0" | cut -d ' ' -f 1`
git pull
[ "$MD5" == "`md5sum \"$0\" | cut -d ' ' -f 1`" ] && {
  bash "$0"
  exit $?
}


docker run -d -p 8080:8080 openstackswift/saio
