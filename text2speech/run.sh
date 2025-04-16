#!/bin/bash


IPV4="172.20.10.3"
SCHEMA="S5"
TEXTES=("1Ko.txt" "5Ko.txt" "12Ko.txt")


mkdir -p "result/energy/$SCHEMA/" 

for TEXT in "${TEXTES[@]}"; do

  echo "$TEXT"
  #echo -e "$TEXT" >> perfEnergy.txt

  for (( i = 1; i <= 1 ; i++ )); do

    # Launch cpu-energy-meter in background and save her PID
    cpu-energy-meter -r >> "result/energy/$SCHEMA/$TEXT" &
    METER_PID=$!

    wsk action invoke  "demo/$SCHEMA" -r \
        --param ipv4   "$IPV4" \
        --param schema "$SCHEMA" \
        --param text   "$TEXT" 

    kill -SIGINT $METER_PID

    #perf stat -o result/perfEnergyS1.txt --append -e power/energy-pkg/ -e power/energy-cores/ wsk action invoke demo/text2speech -r --param ipv4 "$IPV4"   --param schema "S1" --param text "$TEXT" >> "result/perf.txt"

      echo -e "$i"

      sleep 2

    done

  done


