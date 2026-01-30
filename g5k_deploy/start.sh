#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")/.."
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" $@
  exit $?
}


source ./g5k_deploy/partial_start.sh


ITERATIONS=`cat .iterations`
RUNS=`cat .runs`

mkdir -p logs
echo "Deploying the demo..."
for HOST in "${OW_HOSTS[@]}"; do
  echo "  on $HOST"
  ssh root@$HOST "./greenfaas/g5k_deploy/run_text2speech.sh '$(IFS=','; echo "${SWIFT_HOSTS[*]}")' '$ITERATIONS' '$RUNS' >tts.log 2>&1" >/dev/null 2>&1 &&
    scp -r root@$HOST:/root/greenfaas/energy_results . &&
    scp root@$HOST:/root/tts.log logs/$HOST.log &
done

echo "Waiting for tasks to finish..."
while [ -n "$(tr -d ' ' <<<"${OW_HOSTS[@]}")" ]; do
  for HOST in "${OW_HOSTS[@]}"; do
    if [ -f "logs/$HOST.log" ]; then
      echo "  on $HOST: done"
      OW_HOSTS=("${OW_HOSTS[@]/$HOST}")
    fi
  done
  sleep 10s
done
