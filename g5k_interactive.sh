#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" $@
  exit $?
}


oarsub -t monitor=wattmetre_power_watt -t deploy -l {"core_count >= 12 AND memnode >= 32768 AND wattmeter=YES AND NOT cluster IN ('parasilo') AND (cluster!='paradoxe' OR host LIKE 'paradoxe-_.%' OR host LIKE 'paradoxe-1_.%' OR host LIKE 'paradoxe-2_.%' OR host LIKE 'paradoxe-30.%' OR host LIKE 'paradoxe-31.%' OR host LIKE 'paradoxe-32.%')"}/cluster=1/host=1+{"core_count >= 4 AND memnode >= 8192"}/host=1,walltime=1 -I
