#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" $@
  exit $?
}


if [ $(grep "help" <<<"$*") ]; then
  echo "Usage: $0 [<walltime>] [<nb_openwhisk_instances>] [<nb_swift_instances>] [<iterations>] [<runs>]"
  echo "  <walltime>: walltime for the job in format HH[:MM[:SS]], default: 2 (for 2h)"
  echo "  <nb_openwhisk_instances>: number of Openwhisk instances to deploy, default: value from .openwhisk_instances"
  echo "  <nb_swift_instances>: number of Swift instances to deploy, default: value from .swift_instances"
  echo "  <iterations>: number of iterations per run, default: value from .iterations"
  echo "  <runs>: number of runs, default: value from .runs"
  exit 0
fi

if [ -z "$1" ]; then
  WT=2
else
  WT=$1
fi

if [ -z "$2" ]; then
  NB_OW=`cat .openwhisk_instances`
else
  NB_OW=$2
fi

if [ -z "$3" ]; then
  NB_SWIFT=`cat .swift_instances`
else
  NB_SWIFT=$3
fi

if [ -z "$4" ]; then
  ITERATIONS=`cat .iterations`
else
  ITERATIONS=$4
fi

if [ -z "$5" ]; then
  RUNS=`cat .runs`
else
  RUNS=$5
fi


if [ "$(echo "$WT" | cut -d ':' -f 1)" -ge 6 ]; then
  NIGHT_OR_DAY="night"
else
  NIGHT_OR_DAY="day"
fi

oarsub -t $NIGHT_OR_DAY -t destructive -t monitor=wattmetre_power_watt -t deploy -l {"core_count >= 12 AND memnode >= 32768 AND wattmeter=YES"}/cluster=1/host=$NB_OW+{"core_count >= 4 AND memnode >= 8192"}/host=$NB_SWIFT,walltime=$WT -O "logs/deploy_logs.%jobid%.stdout" -E "logs/deploy_logs.%jobid%.stderr" "./g5k_deploy/start.sh $NB_OW $ITERATIONS $RUNS"
