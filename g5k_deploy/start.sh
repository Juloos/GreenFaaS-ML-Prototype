#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$SCRIPTDIR")/.."
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH"
  exit $?
}


NB_OW=`cat .openwhisk_instances`

HOSTS=`oarprint host -P host,cluster,core_count,memnode,wattmeter`


######################
# Resource selection #
######################

echo "Selecting resources from"
echo "  host cluster core_count memnode wattmeter"
echo -e "$HOSTS" | sed "s/^/  /"
echo "With NB_OW=$NB_OW"
echo "     PWD=$PWD"

mapfile -t OW_ELIGIBLE < <(
  echo -e $HOSTS | awk '$3 >= 12 && $4 >= 16384 && $5 == "YES"'
)

# Group OW eligible hosts by cluster
declare -A CLUSTERS
for line in "${OW_ELIGIBLE[@]}"; do
  read -r host cluster _ <<< "$line"
  CLUSTERS["$cluster"]+="$host "
done

# Find a cluster with at least NB_OW eligible hosts
for cluster in "${!CLUSTERS[@]}"; do
  hosts=(${CLUSTERS[$cluster]})
  if (( ${#hosts[@]} >= NB_OW )); then
    OW_HOSTS=("${hosts[@]:0:NB_OW}")
    break
  fi
done

# Put everything else as Swift hosts
SWIFT_HOSTS=()
for line in "${HOSTS[@]}"; do
  read -r host cluster _ <<< "$line"
  # Skip OW hosts
  skip=false
  for ow in "${OW_HOSTS[@]}"; do
    [[ "$host" == "$ow" ]] && skip=true && break
  done
  $skip || SWIFT_HOSTS+=("$host")
done


###############
# Deployemeny #
###############

echo "Deploying Openwhisk on $OW_HOSTS"
echo $OW_HOSTS | kadeploy3 -f - -a ~/public/openwhisk_env.yml -p SYSTEM --custom-steps ~/public/partitioning.yml |& sed "s/^/  /"

echo "Starting up Openwhisk..."
for HOST in $OW_HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "./greenfaas/g5k_deploy/run_openwhisk.sh" &
done


echo "Deploying Swift on $SWIFT_HOSTS"
echo $SWIFT_HOSTS | kadeploy3 -f - -a ~/public/swift_env.yml -p SYSTEM --custom-steps ~/public/partitioning.yml |& sed "s/^/  /"

echo "Starting up Swift..."
for HOST in $SWIFT_HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "./greenfaas/g5k_deploy/run_swift.sh" &
done


echo "Waiting for Openwhisk instances to be up and running..."
sleep 5m
TMP_OW_HOSTS=$OW_HOSTS
while [ -n "$TMP_OW_HOSTS" ]; do
  for HOST in $TMP_OW_HOSTS; do
    ./bin/wsk -i --apihost "$HOST:31001" --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP" list >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "  on $HOST: up"
      TMP_OW_HOSTS=${TMP_OW_HOSTS//$HOST/}
    fi
  done
  sleep 1s
done


ITERATIONS=`cat .iterations`
RUNS=`cat .runs`

mkdir -p logs
echo "Deploying the demo..."
for HOST in $OW_HOSTS; do
  echo "  on $HOST"
  ssh root@$HOST "./greenfaas/run_text2speech.sh '`echo $SWIFT_HOSTS | sed \"s/ /,/g\"`' '$ITERATIONS' '$RUNS' >tts.log 2>&1" >/dev/null 2>&1 && \
    scp -r root@$HOST:/root/greenfaas/energy_results . && \
    scp root@$HOST:/root/tts.log logs/$HOST.log &
done

echo "Waiting for tasks to finish..."
while [ -n "$OW_HOSTS" ]; do
  for HOST in $OW_HOSTS; do
    if [ -f "logs/$HOST.log" ]; then
      echo "  on $HOST: done"
      OW_HOSTS=${OW_HOSTS//$HOST/}
    fi
  done
  sleep 10s
done
