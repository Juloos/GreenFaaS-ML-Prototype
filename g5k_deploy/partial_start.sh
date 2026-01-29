#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")/.."
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" $@
  exit $?
}


NB_OW=`cat .openwhisk_instances`


######################
# Resource selection #
######################

mapfile -t HOSTS < <(
  oarprint host -P host,cluster,core_count,memnode,wattmeter
)

echo "Selecting resources from"
echo "  host cluster core_count memnode wattmeter"
printf '  %s\n' "${HOSTS[@]}"
echo "With"
echo "  NB_OW=$NB_OW"

mapfile -t OW_ELIGIBLE < <(
  printf '%s\n' "${HOSTS[@]}" | awk '$3 >= 12 && $4 >= 16384 && $5 == "YES"'
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
  read -r host _ <<< "$line"
  # Skip OW hosts
  skip=false
  for ow in "${OW_HOSTS[@]}"; do
    [[ "$host" == "$ow" ]] && skip=true && break
  done
  $skip || SWIFT_HOSTS+=("$host")
done


##############
# Deployment #
##############

echo "Deploying Openwhisk on ${OW_HOSTS[@]}"
IFS='\n' echo "${OW_HOSTS[*]}" | kadeploy3 -f - -a ~/public/openwhisk_env.yml -p SYSTEM --custom-steps ~/public/partitioning.yml |& sed "s/^/  /"

echo "Starting up Openwhisk..."
for HOST in "${OW_HOSTS[@]}"; do
  echo "  on $HOST"
  ssh root@$HOST "./greenfaas/g5k_deploy/run_openwhisk.sh >openwhisk.log 2>&1" >/dev/null 2>&1 &
done


echo "Deploying Swift on ${SWIFT_HOSTS[@]}"
IFS='\n' echo "${SWIFT_HOSTS[*]}" | kadeploy3 -f - -a ~/public/swift_env.yml -p SYSTEM --custom-steps ~/public/partitioning.yml |& sed "s/^/  /"

echo "Starting up Swift..."
for HOST in "${SWIFT_HOSTS[@]}"; do
  echo "  on $HOST"
  ssh root@$HOST "./greenfaas/g5k_deploy/run_swift.sh >swift.log 2>&1" >/dev/null 2>&1 &
done


echo "Waiting for Openwhisk to be up and running..."
sleep 5m
TMP_OW_HOSTS=("${OW_HOSTS[@]}")
while [ ${#TMP_OW_HOSTS[@]} -gt 0 ]; do
  for HOST in "${TMP_OW_HOSTS[@]}"; do
    ./bin/wsk -i --apihost "$HOST:31001" --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP" list >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "  on $HOST: up"
      TMP_OW_HOSTS=("${TMP_OW_HOSTS[@]/$HOST}")
    fi
  done
  sleep 1s
done
