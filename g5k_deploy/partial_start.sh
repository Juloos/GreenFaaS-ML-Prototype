#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")/.."
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" $@
  exit $?
}


if [ -z "$1" ]; then
  NB_OW=`cat .openwhisk_instances`
else
  NB_OW=$1
fi

SSHFLAGS="-o StrictHostKeyChecking=no"


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
  read -r host cluster core_count _ <<< "$line"
  ######## Special cluster handling (splitting)
  if [[ "$cluster" == "paradoxe" ]]; then  # paradoxe-[1-32]
    if (( 1 <= $(grep -o [0-9]* <<<"$cluster" | head -n 1) <= 32 )); then
      CLUSTERS["good-paradoxe"]+="$host "
      CORES["good-paradoxe"]=$core_count
    else
      CLUSTERS["bad-paradoxe"]+="$host "
      CORES["bad-paradoxe"]=$core_count
    fi
    continue
  fi
  ########
  CLUSTERS["$cluster"]+="$host "
  CORES["$cluster"]=$core_count
done

# Find all clusters with at least NB_OW eligible hosts, then take the one with most cores
cores_max=0
for cluster in "${!CLUSTERS[@]}"; do
  hosts=(${CLUSTERS[$cluster]})
  ######## Special cluster handling (blacklist)
  if [[ "$cluster" == "parasilo" ]]; then continue; fi
  ########
  if (( ${#hosts[@]} >= NB_OW && ${CORES["$cluster"]} > $cores_max )); then
    OW_HOSTS=(${hosts[@]:0:NB_OW})
    cores_max=${CORES["$cluster"]}
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

export OW_HOSTS
export SWIFT_HOSTS


##############
# Deployment #
##############

echo "Deploying Openwhisk on ${OW_HOSTS[@]}"
printf '%s\n' "${OW_HOSTS[@]}" | kadeploy3 -f - -a ~/public/openwhisk_env.yml -p TMP --force-steps "SetDeploymentMiniOS|SetDeploymentMiniOSUntrusted:0:900&BroadcastEnv|BroadcastEnvKascade:0:1800&BootNewEnv|BootNewEnvKexec:0:900,BootNewEnvClassical:0:900,BootNewEnvHardReboot:0:900" |& sed "s/^/  /"

echo "Starting up Openwhisk..."
for HOST in "${OW_HOSTS[@]}"; do
  echo "  on $HOST"
  ssh-keygen -R $HOST |& sed "s/^/    /"
  ssh $SSHFLAGS root@$HOST "bash -c './greenfaas/g5k_deploy/run_openwhisk.sh |& ts \"[%F %T] \" >ow.log 2>&1 &'" |& sed "s/^/    /"
done


echo "Deploying Swift on ${SWIFT_HOSTS[@]}"
printf '%s\n' "${SWIFT_HOSTS[@]}" | kadeploy3 -f - -a ~/public/swift_env.yml -p TMP |& sed "s/^/  /"

echo "Starting up Swift..."
for HOST in "${SWIFT_HOSTS[@]}"; do
  echo "  on $HOST"
  ssh-keygen -R $HOST |& sed "s/^/    /"
  ssh $SSHFLAGS root@$HOST "bash -c './greenfaas/g5k_deploy/run_swift.sh |& ts \"[%F %T] \" >swift.log 2>&1 &'" |& sed "s/^/    /"
done

echo "Waiting for Swift to be up and running..."
TMP_SWIFT_HOSTS=("${SWIFT_HOSTS[@]}")
waiting_time=0
while [ -n "$(tr -d ' ' <<<"${TMP_SWIFT_HOSTS[@]}")" ]; do
  for HOST in "${TMP_SWIFT_HOSTS[@]}"; do
    curl -I -u "test\:tester:testing" "http://$HOST:8080/auth/v1.0" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "  on $HOST: up"
      TMP_SWIFT_HOSTS=(${TMP_SWIFT_HOSTS[@]/$HOST})
    fi
  done
  sleep 1s
  waiting_time=$((waiting_time + 1))
  if [ $waiting_time -ge 300 ]; then  # 5m should be largely enough
    echo "  timed out"
    exit 1
  fi
done

echo "Waiting for Openwhisk to be up and running..."
sleep 5m
TMP_OW_HOSTS=("${OW_HOSTS[@]}")
waiting_time=0
while [ -n "$(tr -d ' ' <<<"${TMP_OW_HOSTS[@]}")" ]; do
  for HOST in "${TMP_OW_HOSTS[@]}"; do
    # ./bin/wsk -i --apihost "$HOST:31001" --auth "23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP" list >/dev/null 2>&1
    [ -n "$(ssh $SSHFLAGS root@$HOST 'kubectl get pods -n openwhisk | grep "owdev-install-packages-.*Completed"' 2>/dev/null)" ]
    if [ $? -eq 0 ]; then
      echo "  on $HOST: up"
      TMP_OW_HOSTS=(${TMP_OW_HOSTS[@]/$HOST})
    fi
  done
  sleep 1s
  waiting_time=$((waiting_time + 1))
  if [ $waiting_time -ge 900 ]; then  # 15m + 5m should be largely enough
    echo "  timed out"
    exit 1
  fi
done
