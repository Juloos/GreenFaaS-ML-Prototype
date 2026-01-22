#!/bin/bash

cd "$(dirname "$0")"


#TODO: deploy ow and swift seperately with the cooked images


if [ -z "$1" ]; then
  N_OW_HOSTS=1
else
  N_OW_HOSTS=$1
fi


HOSTS=`oarprint host | cut -d '.' -f 1 | tr -s '\n' ' '`
OW_HOSTS=`echo $HOSTS | cut -d ' ' -f 1-$N_OW_HOSTS`
SWIFT_HOSTS=`echo $HOSTS | cut -d ' ' -f $(($N_OW_HOSTS + 1))-`
echo "Using OpenWhisk hosts: $OW_HOSTS"
echo "Using Swift hosts: $SWIFT_HOSTS"


if [ -z "$1" ] || [ "$1" = "false" ]; then
  echo "Deploying on $HOSTS"
  kadeploy3 -a openwhisk_env.yaml
fi

echo "Updating git..."
for HOST in $HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "cd GreenFaaS-ML-Prototype ; git checkout NoML-Energy-Monitoring ; git pull" >/dev/null 2>&1
done

echo "Launching OpenWhisk..."
for HOST in $HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "nohup ./GreenFaaS-ML-Prototype/run_openwhisk.sh </dev/null &" >/dev/null 2>&1 &
done

echo "Waiting a bit to make sure everything is up and running..."
sleep 1m

IPV4=`cat .ipv4`
ITERATIONS=`cat .iterations`
echo "Using ipv4=$IPV4, iterations=$ITERATIONS"

mkdir -p logs
echo "Deploying the demo..."
for HOST in $HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "./GreenFaaS-ML-Prototype/run_text2speech.sh '$IPV4' '$ITERATIONS' >tts.log 2>&1" >/dev/null 2>&1 && \
    scp -r root@$HOST:/root/GreenFaaS-ML-Prototype/energy_results . && \
    scp root@$HOST:/root/tts.log logs/$HOST.log &
done

echo "Waiting for all hosts to finish..."
while [ -n "$HOSTS" ]; do
  for HOST in $HOSTS; do
    if [ -f "logs/$HOST.log" ]; then
      echo "  on $HOST: done"
      HOSTS=${HOSTS//$HOST/}
    fi
  done
  sleep 10s
done
