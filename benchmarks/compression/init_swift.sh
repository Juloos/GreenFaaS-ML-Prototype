#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")/../.."
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" "$@"
  exit $?
}


echo "Generating benchmark files..."
{ head -c 4M </dev/urandom >$(dirname "$SCRIPTPATH")/storage_objects/4Mo.bin; echo "  4Mo.bin"; } &
{ head -c 64M </dev/urandom >$(dirname "$SCRIPTPATH")/storage_objects/64Mo.bin; echo "  64Mo.bin"; } &
{ head -c 1024M </dev/urandom >$(dirname "$SCRIPTPATH")/storage_objects/1024Mo.bin; echo "  1024Mo.bin"; } &
{ head -c 4G </dev/urandom >$(dirname "$SCRIPTPATH")/storage_objects/4Go.bin; echo "  4Go.bin"; } &
wait


source benchmarks/_common/init_swift.sh
