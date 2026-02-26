#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" "$@"
  exit $?
}

source .sql.sh


oarsub -t monitor=wattmetre_power_watt -t deploy -l {"$SQL0"}/cluster=1/host=1+{"$SQL1"}/host=1,walltime=1 -I
