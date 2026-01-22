#!/bin/bash

#OAR -p "core_count >= 12 AND memnode >= 32768 AND wattmeter=YES"
#OAR -t monitor=wattmetre_power_watt
#OAR -t destructive
#OAR -t deploy


cd ~/greenfaas
git pull > /dev/null 2>&1 || {
  git reset --hard
  git pull
  bash $0
  exit $?
}


cd "$(dirname "$0")"


N_OW_HOSTS=`cat .openwhisk_instances`

HOSTS=`oarprint host | cut -d '.' -f 1 | tr -s '\n' ' '`
OW_HOSTS=`echo $HOSTS | cut -d ' ' -f 1-$N_OW_HOSTS`
SWIFT_HOSTS=`echo $HOSTS | cut -d ' ' -f $(($N_OW_HOSTS + 1))-`


echo "Deploying Openwhisk on $OW_HOSTS"
echo $OW_HOSTS | kadeploy3 -f - -a ~/public/openwhisk_env.yml -p SYSTEM --custom-steps ~/public/partitioning.yml | & sed "s/^/  /"

echo "Starting up Openwhisk..."
for HOST in $OW_HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "./greenfaas/g5k_deploy/run_openwhisk.sh" &
done


echo "Deploying Swift on $SWIFT_HOSTS"
echo $SWIFT_HOSTS | kadeploy3 -f - -a ~/public/swift_env.yml -p SYSTEM --custom-steps ~/public/partitioning.yml | & sed "s/^/  /"

echo "Starting up Swift..."
for HOST in $SWIFT_HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "./g5k_deploy/run_swift.sh" &
done


echo "Waiting for Openwhisk instances to be up and running..."
sleep 5m
TMP_OW_HOSTS=$OW_HOSTS
while [ -n "$TMP_OW_HOSTS" ]; do
  for HOST in $TMP_OW_HOSTS; do
    ./bin/wsk -i --apihost "$HOST:31001" --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP" list >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "  on $HOST: up"
      TMP_OW_HOSTS=${TMP_OW_HOSTS//$HOST/}
    fi
  done
  sleep 1s
done


ITERATIONS=`cat .iterations`
RUNS=`cat .runs`

mkdir -p logs
echo "Deploying the demo..."
for HOST in $HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "./greenfaas/run_text2speech.sh '`echo $SWIFT_HOSTS | sed \"s/ /,/g\"`' '$ITERATIONS' '$RUNS' >tts.log 2>&1" >/dev/null 2>&1 && \
    scp -r root@$HOST:/root/greenfaas/energy_results . && \
    scp root@$HOST:/root/tts.log logs/$HOST.log &
done

echo "Waiting for tasks to finish..."
while [ -n "$OW_HOSTS" ]; do
  for HOST in $OW_HOSTS; do
    if [ -f "logs/$HOST.log" ]; then
      echo "  on $HOST: done"
      OW_HOSTS=${OW_HOSTS//$HOST/}
    fi
  done
  sleep 10s
done
