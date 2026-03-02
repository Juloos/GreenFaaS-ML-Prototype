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


if [[ $(grep "help" <<<"$*") ]]; then
  echo "Usage: $0 [<walltime>] [<nb_openwhisk_instances>] [<nb_swift_instances>] [<iterations>] [<runs>] [day|night]"
  echo "  <walltime>: walltime for the job in format HH[:MM[:SS]], default: 2 (for 2h)"
  echo "  <nb_openwhisk_instances>: number of Openwhisk instances to deploy, default: 1"
  echo "  <nb_swift_instances>: number of Swift instances to deploy, default: 3"
  echo "  <iterations>: number of iterations per run, default: 12"
  echo "  <runs>: number of runs, default: 10"
  echo "  [day|night]: whether to schedule the job during the day or night, default: auto"
  exit 0
fi

if [ -z "$1" ]; then
  WT=2
else
  WT=$1
fi

if [ -z "$2" ]; then
  NB_OW=1
else
  NB_OW=$2
fi

if [ -z "$3" ]; then
  NB_SWIFT=3
else
  NB_SWIFT=$3
fi

if [ -z "$4" ]; then
  ITERATIONS=12
else
  ITERATIONS=$4
fi

if [ -z "$5" ]; then
  RUNS=10
else
  RUNS=$5
fi

if [[ "$6" == "day" || "$6" == "night" ]]; then
  NIGHT_OR_DAY=$6
else
  h=$(cut -d ':' -f 1 <<<"$WT:0:0")
  m=$(cut -d ':' -f 2 <<<"$WT:0:0")
  s=$(cut -d ':' -f 3 <<<"$WT:0:0")
  deadline=$(date -d "now + $h hours $m minutes $s seconds" +%H)
  if [[ $h -ge 4 || $deadline -ge 19 ]]; then
    NIGHT_OR_DAY="night"
  else
    NIGHT_OR_DAY="day"
  fi
fi

largs="{$SQL_OW}/cluster=1/host=$NB_OW"
if (( $NB_SWIFT > 0 )); then
  largs+="+{$SQL_SWIFT}/host=$NB_SWIFT"
fi

echo "Submitting job..."
oarsub -t $NIGHT_OR_DAY -t monitor=wattmetre_power_watt -t deploy -l $largs,walltime=$WT -O "logs/deploy_logs.%jobid%.stdout" -E "logs/deploy_logs.%jobid%.stderr" -n "$WT $NB_OW $NB_SWIFT $ITERATIONS $RUNS $NIGHT_OR_DAY" "./g5k_deploy/start.sh $NB_OW $ITERATIONS $RUNS"
echo "  Done. Reproduce with: $0 $WT $NB_OW $NB_SWIFT $ITERATIONS $RUNS $NIGHT_OR_DAY"
echo "$0 $WT $NB_OW $NB_SWIFT $ITERATIONS $RUNS $NIGHT_OR_DAY" >>~/.greenfaas_submit_history
