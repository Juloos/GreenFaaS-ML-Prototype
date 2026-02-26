#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")/.."
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" "$@"
  exit $?
}


shift_left() {
  local -n arr=$1
  local first_element=${arr[0]}
  for ((i=0; i<${#arr[@]}-1; i++)); do
    arr[i]=${arr[i+1]}
  done
  arr[-1]=$first_element
}


# $1 is NB_OW
source ./g5k_deploy/partial_start.sh "$1"


if [ -z "$2" ]; then
  ITERATIONS=`cat .iterations`
else
  ITERATIONS=$2
fi

if [ -z "$3" ]; then
  RUNS=`cat .runs`
else
  RUNS=$3
fi


echo "Deploying the demo..."
for HOST in "${OW_HOSTS[@]}"; do
  echo "  on $HOST"
  ssh -o StrictHostKeyChecking=no root@$HOST "bash -c \"./greenfaas/g5k_deploy/run_text2speech.sh '$(IFS=','; echo "${SWIFT_HOSTS[*]}")' '$ITERATIONS' '$RUNS' |& ts '[%F %T] ' >tts.log 2>&1 &\"" |& sed "s/^/    /"
  shift_left SWIFT_HOSTS
done

echo "Waiting for tasks to finish..."
while [ -n "$(tr -d ' ' <<<"${OW_HOSTS[@]}")" ]; do
  for HOST in "${SWIFT_HOSTS[@]}"; do
    HHOSTNAME="$(cut -d '.' -f 1 <<<"$HOST")"
    if [[ -z "$HHOSTNAME" ]]; then continue; fi
    scp root@$HOST:/root/swift.log logs/$OAR_JOB_ID.$HHOSTNAME.swift.log |& sed "s/^/  $HHOSTNAME.swift: /"
  done
  for HOST in "${OW_HOSTS[@]}"; do
    HHOSTNAME="$(cut -d '.' -f 1 <<<"$HOST")"
    if [[ -z "$HHOSTNAME" ]]; then continue; fi
    scp root@$HOST:/root/ow.log logs/$OAR_JOB_ID.$HHOSTNAME.ow.log |& sed "s/^/  $HHOSTNAME.ow: /"
    scp root@$HOST:/root/tts.log logs/$OAR_JOB_ID.$HHOSTNAME.tts.log |& sed "s/^/  $HHOSTNAME.tts: /"
    if [[ "$(grep "Done" logs/$OAR_JOB_ID.$HHOSTNAME.tts.log)" ]]; then
      mkdir -p ./energy_results/${ITERATIONS}i-${RUNS}r-${1}ow_${OAR_JOB_ID}
      scp -r root@$HOST:/root/greenfaas/energy_results/$HHOSTNAME ./energy_results/${ITERATIONS}i-${RUNS}r-${1}ow_${OAR_JOB_ID} |& sed "s/^/  $HHOSTNAME: /"
      echo "  on $HOST: done"
      OW_HOSTS=(${OW_HOSTS[@]/$HOST})
    fi
  done
  sleep 10s
done
