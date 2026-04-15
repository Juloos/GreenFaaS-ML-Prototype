#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")/../.."
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" "$@"
  exit $?
}


echo "Reassembling storage archive..."
cat $(dirname "$SCRIPTPATH")/storage_archive/part-* >$(dirname "$SCRIPTPATH")/storage_archive.tar.bz2 |& sed "s/^/  /"

echo "Extracting benchmark files..."
tar -xvf $(dirname "$SCRIPTPATH")/storage_archive.tar.bz2 -C $(dirname "$SCRIPTPATH")/storage_objects |& sed "s/^/  /"


source benchmarks/_common/init_swift.sh
