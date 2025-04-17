#!/bin/sh

cd "$(dirname "$0")"

if [ -z "$1" ]; then
  echo "Usage: $0 <ipv4>"
  exit 1
fi

chmod 700 ./bin/wsk*
./bin/wsk property set --apihost "http://172.17.0.1:3233" --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP"
./bin/wskdeploy -m ./text2speech/manifest.yaml

SCHEMAS=("S1" "S2" "S3" "S4" "S5")
TEXTES=("1Ko.txt" "5Ko.txt" "12Ko.txt")

for SCHEMA in "${SCHEMAS[@]}"; do
  mkdir -p "text2speech/result/energy/$SCHEMA/"
  for TEXT in "${TEXTES[@]}"; do
    echo -e "Starting $SCHEMA with $TEXT at $(date)"
    for (( i = 0; i < 101 ; i++ )); do
      ./bin/wsk action invoke "demo/$SCHEMA" -r \
        --param ipv4 "$1" \
        --param schema "$SCHEMA" \
        --param text "$TEXT"
    done
  done
done
