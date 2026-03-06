#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")/../.."
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" "$@"
  exit $?
}


cd "$(dirname "$0")"

echo "Uploading benchmark files to container storage..."
swift upload "whiskcontainer" storage_objects --object-name "." --skip-identical -A "http://localhost:8080/auth/v1.0" -U "test:tester" -K "testing" |& sed "s/^/  /"
