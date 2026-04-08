#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")/../.."
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" "$@"
  exit $?
}


if [ -z "$1" ]; then
  echo "Usage: $0 <ipv4s> [<iterations>] [<runs>] [<texts>]"
  exit 1
else
  IFS=',' read -ra IPV4LIST <<< "$1"
fi

if [ -z "$2" ]; then
  ITERATIONS=12
else
  ITERATIONS=$2
fi

if [ -z "$3" ]; then
  RUNS=10
else
  RUNS=$3
fi

if [ -z "$4" ]; then
  TEXTS=($(ls "$(dirname "$SCRIPTPATH")/storage_objects" | grep -E "^.*\.txt$" | tr -s '\n' ' '))
else
  IFS=',' read -ra TEXTS <<< "$4"
fi
MIN_TEXT=$(ls -S "$(dirname "$SCRIPTPATH")/storage_objects" | tail -n 1)
echo "Using \"text\" from : ${TEXTS[@]}"

wsk -i property set --apihost "https://localhost:31001" --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP"
wskdeploy -m "$(dirname "$SCRIPTPATH")/src/manifest.yml" ||
  { echo "Failed to deploy, make sure Openwhisk is running."; exit 1; }

SCHEMAS="S1 S3 S4 S5"

HOSTNAME=$(hostname)
SITE=$(cut -d '.' -f 2 <<<"${IPV4LIST[0]}")  # Assuming the job is not cross-site

echo Waiting 5m...
start=$(date +%FT%T)
sleep 5m
end=$(date +%FT%T)
echo "Pulling from https://api.grid5000.fr/stable/sites/$SITE/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end"
mkdir -p "energy_results/$HOSTNAME"
curl -sk "https://api.grid5000.fr/stable/sites/$SITE/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end" \
  >"energy_results/$HOSTNAME/idle.json" 2>/dev/null

IPV4I=0
for SCHEMA in $SCHEMAS; do
  echo "schema $SCHEMA"
  echo "  warmup"
  activation=`wsk -i action invoke "demo/$SCHEMA" \
      -p ipv4 "${IPV4LIST[0]}" \
      -p schema "$SCHEMA" \
      -p text "$MIN_TEXT" \
      -p ttsid "$HOSTNAME-$SCHEMA-warmup" \
    | cut -d ' ' -f 6`
  while ( wsk -i activation get "$activation" >/dev/null 2>&1 ; test $? -ne 0 ); do
    sleep 1s
  done
  for TEXT in "${TEXTS[@]}"; do
    echo "  for text $TEXT"
    start=$(date +%FT%T)
    for (( run = 0 ; run < $RUNS ; run++ )); do
      rm -f activations
      echo "    run $run"
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
      echo "    waiting for activations to complete..."
      while [ -s activations ]; do
        for ACTIVATION in $(cat activations); do
          wsk -i activation get "$ACTIVATION" >/dev/null 2>&1
          if [ $? -eq 0 ]; then
            sed -i "/$ACTIVATION/d" activations
            echo "      got $ACTIVATION"
          fi
        done
        sleep 1s
      done
    done
    end=$(date +%FT%T)
    echo "Pulling from https://api.grid5000.fr/stable/sites/$SITE/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end"
    mkdir -p "energy_results/$HOSTNAME/$TEXT"
    curl -sk "https://api.grid5000.fr/stable/sites/$SITE/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end" \
      >"energy_results/$HOSTNAME/$TEXT/$SCHEMA.json" 2>/dev/null
  done
done

echo "Cleaning up swift files from host's container..."
for IPV4 in "${IPV4LIST[@]}"; do
  echo "  for ipv4 $IPV4"
  swift delete "whiskcontainer" --prefix "$HOSTNAME" -A "http://$IPV4:8080/auth/v1.0" -U "test:tester" -K "testing" |& sed "s/^/    /"
done

echo "Creating manifest..."
tee "energy_results/$HOSTNAME/manifest.txt" <<EOF |& sed "s/^/  /"
HOSTNAME=$HOSTNAME
IPV4LIST=(${IPV4LIST[@]})
TEXTS=(${TEXTS[@]})
ITERATIONS=$ITERATIONS
RUNS=$RUNS
EOF

echo "Done"
