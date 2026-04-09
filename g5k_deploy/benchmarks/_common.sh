#!/bin/bash


if [[ "$0" == "${BASH_SOURCE[0]}" ]]; then  # Not sourced
  MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
  SCRIPTPATH="$(realpath "$0")"
  cd "$(dirname "$0")/../.."
  git pull
  [ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
    bash "$SCRIPTPATH" "$@"
    exit $?
  }
fi


shift_left() {
  local -n arr=$1
  local first_element=${arr[0]}
  for ((i=0; i<${#arr[@]}-1; i++)); do
    arr[i]=${arr[i+1]}
  done
  arr[-1]=$first_element
}


# $1 is NB_OW, $2 is NB_SWIFT
pushd .
source ./g5k_deploy/partial_start.sh "$1" "$2"
popd

ITERATIONS="$3"
RUNS="$4"
BENCHARGS=("${@:5:$#}")


echo "Initializing the Swift hosts..."
for HOST in "${SWIFT_HOSTS[@]}"; do
  HHOSTNAME="$(cut -d '.' -f 1 <<<"$HOST")"
  ssh $SSHFLAGS root@$HOST ./greenfaas/benchmarks/$BENCHMARK/init_swift.sh |& sed "s/^/  $HHOSTNAME: /" &
done
wait

echo "Deploying the benchmark..."
for HOST in "${OW_HOSTS[@]}"; do
  echo "  on $HOST"
  ssh $SSHFLAGS root@$HOST "bash -c \"./greenfaas/benchmarks/$BENCHMARK/run.sh '$(IFS=','; echo "${SWIFT_HOSTS[*]}")' '$ITERATIONS' '$RUNS' '${BENCHARGS[@]}' |& ts '[%F %T] ' >$BCHMK.log 2>&1 &\"" |& sed "s/^/    /"
  shift_left SWIFT_HOSTS
done

echo "Waiting for tasks to finish..."
while [ -n "$(tr -d ' ' <<<"${OW_HOSTS[@]}")" ]; do
  for HOST in "${SWIFT_HOSTS[@]}"; do
    HHOSTNAME="$(cut -d '.' -f 1 <<<"$HOST")"
    if [[ -z "$HHOSTNAME" ]]; then continue; fi
    scp root@$HOST:/root/swift.log logs/$BENCHMARK.$OAR_JOB_ID.$HHOSTNAME.swift.log |& sed "s/^/  $HHOSTNAME.swift: /"
  done
  for HOST in "${OW_HOSTS[@]}"; do
    HHOSTNAME="$(cut -d '.' -f 1 <<<"$HOST")"
    if [[ -z "$HHOSTNAME" ]]; then continue; fi
    scp root@$HOST:/root/ow.log logs/$BENCHMARK.$OAR_JOB_ID.$HHOSTNAME.ow.log |& sed "s/^/  $HHOSTNAME.ow: /"
    scp root@$HOST:/root/$BCHMK.log logs/$BENCHMARK.$OAR_JOB_ID.$HHOSTNAME.$BCHMK.log |& sed "s/^/  $HHOSTNAME.$BCHMK: /"
    if [[ "$(grep "Done" logs/$BENCHMARK.$OAR_JOB_ID.$HHOSTNAME.$BCHMK.log)" ]]; then
      mkdir -p ./energy_results/$BCHMK_${ITERATIONS}i-${RUNS}r-${1}ow_${OAR_JOB_ID}
      scp -r root@$HOST:/root/greenfaas/energy_results/$HHOSTNAME ./energy_results/$BCHMK_${ITERATIONS}i-${RUNS}r-${1}ow_${OAR_JOB_ID} |& sed "s/^/  $HHOSTNAME: /"
      echo "  on $HOST: done"
      OW_HOSTS=(${OW_HOSTS[@]/$HOST})
    fi
  done
  sleep 10s
done
