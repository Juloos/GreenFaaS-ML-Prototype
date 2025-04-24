#!/bin/bash

cd "$(dirname "$0")"

HOSTS=`oarprint host | cut -d '.' -f 1 | tr -s '\n' ' '`

# if the first argument is not set, or if it is set to "false", deploy the environment
if [ -z "$1" ] || [ "$1" = "false" ]; then
  echo "Deploying on $HOSTS"
  kadeploy3 -a openwhisk_env.yaml
fi

echo "Updating git..."
for HOST in $HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "cd GreenFaaS-ML-Prototype ; git pull" 2>/dev/null >/dev/null
done

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
  ssh root@$HOST "./GreenFaaS-ML-Prototype/run_text2speech.sh" 2>/dev/null >/dev/null && \
    scp -r root@$HOST:/root/GreenFaaS-ML-Prototype/energy_results/$HOST energy_results ; \
    touch "energy_results/${HOST}_done" &
done

echo "Waiting for all hosts to finish..."
for HOST in $HOSTS; do
  while [ ! -f "energy_results/${HOST}_done" ]; do
    sleep 10s
  done
  echo "  on $HOST: done"
  rm "energy_results/${HOST}_done"
done
