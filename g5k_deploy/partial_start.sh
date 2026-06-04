#!/bin/bash


if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then  # Not sourced
  MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
  SCRIPTPATH="$(realpath "$0")"
  cd "$(dirname "$0")/.."
  git pull
  [ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
    bash "$SCRIPTPATH" "$@"
    exit $?
  }
fi

export SSHFLAGS="-o StrictHostKeyChecking=no"


######################
# Resource selection #
######################

mapfile -t HOSTS < <(
  oarprint host -P host,cluster,core_count,memnode
)

mapfile -t OW_ELIGIBLE < <(
  printf '%s\n' "${HOSTS[@]}" | awk '$3 >= 12 && $4 >= 16384'
)

# Group OW eligible hosts by cluster
declare -A CLUSTERS
for line in "${OW_ELIGIBLE[@]}"; do
  read -r host cluster core_count _ <<< "$line"
  ######## Special cluster handling (splitting)
  if [[ "$cluster" == "paradoxe" ]]; then  # paradoxe-[1-32]
    if (( $(grep -o [0-9]* <<<"$host" | head -n 1) <= 32 )); then
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
  ######## Special cluster handling (blacklist)
  if [[ "$cluster" == "parasilo" ]]; then continue; fi
  if [[ "$cluster" == "bad-paradoxe" ]]; then continue; fi
  ########
  hosts=(${CLUSTERS[$cluster]})
  if (( ${#hosts[@]} >= NB_OW && ${CORES["$cluster"]} > $cores_max )); then
    OW_HOSTS=(${hosts[@]:0:NB_OW})
    cores_max=${CORES["$cluster"]}
    break
  fi
done

export OW_HOSTS


##############
# Deployment #
##############

echo "Starting the deployment of Openwhisk on ${OW_HOSTS[@]}"
printf '%s\n' "${OW_HOSTS[@]}" | kadeploy3 -f - -a ~/public/openwhisk_env.yml -p TMP --force-steps "SetDeploymentMiniOS|SetDeploymentMiniOSUntrusted:0:900&BroadcastEnv|BroadcastEnvKascade:0:1800&BootNewEnv|BootNewEnvClassical:0:1200,BootNewEnvHardReboot:0:1200" |& sed "s/^/     ow:   /"
echo "     ow: Starting up Openwhisk..."
for HOST in "${OW_HOSTS[@]}"; do
  echo "     ow:   on $HOST"
  ssh-keygen -R $HOST |& sed "s/^/     ow:   /"
  ssh $SSHFLAGS root@$HOST "bash -c './greenfaas/g5k_deploy/run_openwhisk.sh |& ts \"[%F %T] \" >ow.log 2>&1 &'" |& sed "s/^/     ow:   /"
done

echo "Waiting for Openwhisk to be up and running..."
sleep 5m
TMP_OW_HOSTS=("${OW_HOSTS[@]}")
waiting_time=0
while [ -n "$(tr -d ' ' <<<"${TMP_OW_HOSTS[@]}")" ]; do
  for HOST in "${TMP_OW_HOSTS[@]}"; do
    [ -n "$(ssh $SSHFLAGS root@$HOST 'kubectl get pods -n openwhisk | grep "owdev-install-packages-.*Completed"' 2>/dev/null)" ]
    if [ $? -eq 0 ]; then
      echo "  on $HOST: up"
      TMP_OW_HOSTS=(${TMP_OW_HOSTS[@]/$HOST})
    fi
  done
  sleep 1s
  waiting_time=$((waiting_time + 1))
  if [ $waiting_time -ge 1500 ]; then  # 25m + 5m should be largely enough here also
    echo "  timed out"
    exit 1
  fi
done
