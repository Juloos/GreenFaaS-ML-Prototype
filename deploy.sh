#!/bin/bash

cd "$(dirname "$0")"

HOSTS=`oarprint host | cut -d '.' -f 1 | tr -s '\n' ' '`

if [ -z "$1" ] || [ "$1" = "false" ]; then
  echo "Deploying on $HOSTS"
  kadeploy3 -a openwhisk_env.yaml
fi

echo "Updating git..."
for HOST in $HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "cd GreenFaaS-ML-Prototype ; git pull" >/dev/null 2>&1
done

echo "Launching OpenWhisk..."
for HOST in $HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "nohup ./GreenFaaS-ML-Prototype/run_openwhisk.sh </dev/null &" >/dev/null 2>&1 &
done

echo "Waiting a bit to make sure everything is up and running..."
sleep 1m

IPV4=`cat .ipv4`
echo "Using ipv4=$IPV4"

mkdir -p logs
echo "Deploying the demo..."
for HOST in $HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "./GreenFaaS-ML-Prototype/run_text2speech.sh '$IPV4' >tts.log 2>&1" >/dev/null 2>&1 && \
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
