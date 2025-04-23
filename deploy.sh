#!/bin/bash

HOSTS=`oarprint host`
echo "Running on $HOSTS"

echo "Launching OpenWhisk..."
for (HOST in $HOSTS); do
  ssh root@$HOST "nohup ./GreenFaaS-ML-Prototype/run_openwhisk.sh </dev/null &" &
done

echo "Waiting a bit to make sure everything is up and running..."
sleep 1m

echo "Deploying the demo..."
for (HOST in $HOSTS); do
  ssh root@$HOST "nohup ./GreenFaaS-ML-Prototype/run_text2speech.sh </dev/null &" &
done
