#!/bin/bash

cd "$(dirname "$0")"

HOSTS=`oarprint host | tr -s '\n' ' '`
echo "Deploying on $HOSTS"

kadeploy3 -a openwhisk_env.yaml

echo "Launching OpenWhisk..."
for HOST in $HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "nohup ./GreenFaaS-ML-Prototype/run_openwhisk.sh </dev/null &" 2>/dev/null >/dev/null &
done

echo "Waiting a bit to make sure everything is up and running..."
sleep 30s

echo "Deploying the demo..."
for HOST in $HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "nohup ./GreenFaaS-ML-Prototype/run_text2speech.sh </dev/null &" 2>/dev/null >/dev/null && scp -r root@$HOST:/root/GreenFaaS-ML-Prototype/energy_results energy_results &
done
