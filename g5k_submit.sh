#!/bin/bash


cd "$(dirname "$0")"
git pull > /dev/null 2>&1 || {
  git reset --hard
  git pull
  bash $0
  exit $?
}


NB_OW=`cat .openwhisk_instances`
NB_SWIFT=`cat .swift_instances`

if [ -z "$1" ]; then
  WT=4
else
  WT=$1
fi

if [ "$(echo "$WT" | cut -d ':' -f 1)" -ge 6 ]; then
  NIGHT_OR_DAY="night"
else
  NIGHT_OR_DAY="day"
fi

oarsub -t $NIGHT_OR_DAY -t destructive -t monitor=wattmetre_power_watt -t deploy -l {"core_count >= 12 AND memnode >= 32768 AND wattmeter=YES"}/cluster=1/host=$NB_OW+{"core_count >= 4 AND memnode >= 8192"}/host=$NB_SWIFT,walltime=$WT ./g5k_deploy/start.sh
