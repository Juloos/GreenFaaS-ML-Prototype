#!/bin/bash

cd "$(dirname "$0")"

if [ -z "$1" ]; then
  echo "Usage: $0 <ipv4> [<iterations>]"
  exit 1
else
  IPV4=$1
fi

if [ -z "$2" ]; then
  ITERATIONS=100
else
  ITERATIONS=$2
fi

./bin/wsk property set --apihost "http://172.17.0.1:3233" --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP"
./bin/wskdeploy -m text2speech/manifest.yaml || 
  { echo "Failed to deploy, make sure OpenWhisk is running."; exit 1; }

SCHEMAS="S1 S2 S3 S4 S5"
TEXTS=$(ls swift_files | grep "Ko.txt" | tr -s '\n' ' ')
echo "Using \"text\" from : $TEXTS"

HOSTNAME=$(hostname)
mkdir -p "energy_results/$HOSTNAME/"

echo "Uploading swift files to host's container..."
swift upload "${HOSTNAME}_whiskcontainer" swift_files --object-name "." -A "http://$1:8080/auth/v1.0" -U "test:tester" -K "testing"

echo Waiting 15m...
start=$(date +%FT%T)
sleep 15m
end=$(date +%FT%T)
echo "Pulling from https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end"
curl -sk "https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end" \
  >"energy_results/$HOSTNAME/idle.json" 2>/dev/null

for SCHEMA in $SCHEMAS; do
  mkdir -p "energy_results/$HOSTNAME/$SCHEMA/"
  for TEXT in $TEXTS; do
    start=$(date +%FT%T)
    echo -e "starting $SCHEMA with $TEXT at $start"
    for (( i = -1; i < $ITERATIONS ; i++ )); do
      printf "Doing $i\r"
      ./bin/wsk action invoke "demo/$SCHEMA" -r \
        -p ipv4 "$IPV4" \
        -p schema "$SCHEMA" \
        -p text "$TEXT" \
        -p hostname "$HOSTNAME" \
        >/dev/null
    done
    end=$(date +%FT%T)
    echo "Pulling from https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end"
    curl -sk "https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end" \
      >"energy_results/$HOSTNAME/$SCHEMA/$TEXT.json" 2>/dev/null
  done
done

echo "Cleaning up swift files from host's container..."
swift delete "${HOSTNAME}_whiskcontainer" -A "http://$1:8080/auth/v1.0" -U "test:tester" -K "testing"
