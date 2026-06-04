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


if [ -z "$1" ]; then
  NB_OW=1
else
  NB_OW=$1
fi


if [ -z "$2" ]; then
  WT=1
else
  WT=$2
fi


oarsub -t deploy -l "{$SQL_OW}/cluster=1/host=$NB_OW,walltime=$WT" -I
