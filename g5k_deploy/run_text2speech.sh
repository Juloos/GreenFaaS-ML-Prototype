#!/bin/bash

cd "$(dirname "$0")/.."
MD5=`md5sum "$0" | cut -d ' ' -f 1`
git pull
[ "$MD5" == "`md5sum \"$0\" | cut -d ' ' -f 1`" ] && {
  bash "$0"
  exit $?
}


if [ -z "$1" ]; then
  echo "Usage: $0 <ipv4s> [<iterations>] [<runs>]"
  exit 1
else
  IFS=',' read -ra IPV4LIST <<< "$1"
fi

if [ -z "$2" ]; then
  ITERATIONS=20
else
  ITERATIONS=$2
fi

if [ -z "$3" ]; then
  RUNS=10
else
  RUNS=$3
fi

wsk -i property set --apihost "https://localhost:31001" --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP"
wskdeploy -m text2speech/manifest.yml || 
  { echo "Failed to deploy, make sure Openwhisk is running."; exit 1; }

SCHEMAS="S1 S3 S4 S5"
TEXTS=$(ls swift_files | grep -E "^.*\.txt$" | tr -s '\n' ' ')
echo "Using \"text\" from : $TEXTS"

HOSTNAME=$(hostname)
mkdir -p "energy_results/$HOSTNAME/"

echo "Uploading swift files to host's container..." # Redundant but just in case, also there should be only few hosts running this script
for IPV4 in ${IPV4LIST[@]}; do
  echo "  for ipv4 $IPV4"
  swift upload "whiskcontainer" swift_files --object-name "." --skip-identical -A "http://$IPV4:8080/auth/v1.0" -U "test:tester" -K "testing"
done

echo Waiting 1m...
start=$(date +%FT%T)
sleep 1m
end=$(date +%FT%T)
echo "Pulling from https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end"
curl -sk "https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end" \
  >"energy_results/$HOSTNAME/idle.json" 2>/dev/null

IPV4I=0
for SCHEMA in $SCHEMAS; do
  echo "schema $SCHEMA"
  start=$(date +%FT%T)
  for (( run = 0 ; run < $RUNS ; run++ )); do
    rm -f activations
    echo "  run $run"
    for TEXT in $TEXTS; do
      echo "    for text $TEXT"
      for (( i = 0 ; i < $ITERATIONS ; i++ )); do
        echo "      iteration $i (ipv4: ${IPV4LIST[IPV4I]})"
        wsk -i action invoke "demo/$SCHEMA" \
          -p ipv4 "${IPV4LIST[IPV4I]}" \
          -p schema "$SCHEMA" \
          -p text "$TEXT" \
          -p ttsid "$HOSTNAME-$SCHEMA-$TEXT-$i" \
        | cut -d ' ' -f 6 >>activations
        IPV4I=$(( (IPV4I + 1) % ${#IPV4LIST[@]} ))
      done
    done
    echo "  (run $run) waiting for activations to complete..."
    for ACTIVATION in $(cat activations); do
      while ( wsk -i activation get "$ACTIVATION" >/dev/null 2>&1 ; test $? -ne 0 ); do
        sleep 1s
      done
      echo "    got $ACTIVATION"
    done
  done
  end=$(date +%FT%T)
  echo "Pulling from https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end"
  curl -sk "https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end" \
    >"energy_results/$HOSTNAME/$SCHEMA.json" 2>/dev/null
done

echo "Cleaning up swift files from host's container..."
for IPV4 in ${IPV4LIST[@]}; do
  echo "  for ipv4 $IPV4"
  swift delete "whiskcontainer" -A "http://$IPV4:8080/auth/v1.0" -U "test:tester" -K "testing"
done
