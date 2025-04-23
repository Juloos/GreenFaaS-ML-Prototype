#!/bin/bash

cd "$(dirname "$0")"

if [ -z "$1" ]; then
  echo "Usage: $0 <ipv4>"
  exit 1
fi

chmod 700 ./bin/wsk*
./bin/wsk property set --apihost "http://172.17.0.1:3233" --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP"
./bin/wskdeploy -m text2speech/manifest.yaml

SCHEMAS=("S1" "S2" "S3" "S4" "S5")
TEXTES=`ls -l swift_files | grep "Ko.txt"`
echo "Using "texte" from : $TEXTES"
echo "Make sure you uploaded these files in your Swift distant storage"


HOSTNAME=$(hostname)
mkdir -p "energy_results/$HOSTNAME/"

echo Waiting 15m...
start=$(date +%FT%T)
sleep 15m
end=$(date +%FT%T)
echo "Pulling from https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end"
curl -sk "https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end" \
  >"energy_results/$HOSTNAME/idle.json" 2>/dev/null

for SCHEMA in "${SCHEMAS[@]}"; do
  mkdir -p "energy_results/$HOSTNAME/$SCHEMA/"
  for TEXTE in "${TEXTES[@]}"; do
    start=$(date +%FT%T)
    echo -e "starting $SCHEMA with $TEXTE at $start"
    for (( i = 0; i < 101 ; i++ )); do
      printf "Doing $i\r"
      ./bin/wsk action invoke "demo/$SCHEMA" -r \
        -p ipv4 "$1" \
        -p schema "$SCHEMA" \
        -p text "$TEXTE" \
        >/dev/null
    done
    end=$(date +%FT%T)
    echo "Pulling from https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end"
    curl -sk "https://api.grid5000.fr/stable/sites/lyon/metrics?nodes=$HOSTNAME&metrics=wattmetre_power_watt&start_time=$start&end_time=$end" \
      >"energy_results/$HOSTNAME/$SCHEMA/$TEXTE.json" 2>/dev/null
  done
done
