#!/bin/bash


MD5="$(md5sum "$0" | cut -d ' ' -f 1)"
SCRIPTPATH="$(realpath "$0")"
cd "$(dirname "$0")"
git pull
[ "$MD5" == "$(md5sum "$SCRIPTPATH" | cut -d ' ' -f 1)" ] || {
  bash "$SCRIPTPATH" "$@"
  exit $?
}


source .sql.sh


if [[ $(grep "help" <<<"$*") ]]; then
  echo "Usage: $0 [-w <walltime>] [-ow <nb_openwhisk_instances>] [-sw <nb_swift_instances>] [-i <iterations>] [-r <runs>] [--day|--night] <benchmark> <benchmark_args...>"
  echo "  <benchmark>: name of the benchmark to deploy and run, e.g. text2speech"
  echo "  <benchmark_args...>: arguments to pass to the benchmark script, e.g. for text2speech: <texts>"
  echo "  <walltime>: walltime for the job in format HH[:MM[:SS]], default: 2 (for 2h)"
  echo "  <nb_openwhisk_instances>: number of Openwhisk instances to deploy, default: 1"
  echo "  <nb_swift_instances>: number of Swift instances to deploy, default: 3"
  echo "  <iterations>: number of iterations per run, default: 12"
  echo "  <runs>: number of runs, default: 10"
  echo "  [--day|--night]: whether to schedule the job during the day or night, default: auto"
  exit 0
fi

BENCH=""
BENCHARGS=()
WT=2
NB_OW=1
NB_SWIFT=3
ITERATIONS=12
RUNS=10
NIGHT_OR_DAY="auto"
for (( i = 1 ; i <= $# ; i++ )); do
  let j=$i+1
  case "${!i}" in
    -w) WT="${!j}"; ((i++)) ;;
    -ow) NB_OW="${!j}"; ((i++)) ;;
    -sw) NB_SWIFT="${!j}"; ((i++)) ;;
    -i) ITERATIONS="${!j}"; ((i++)) ;;
    -r) RUNS="${!j}"; ((i++)) ;;
    --day) NIGHT_OR_DAY="day" ;;
    --night) NIGHT_OR_DAY="night" ;;
    *)
      if [[ -z "$BENCH" ]]; then
        BENCH="${!i}"
      else
        BENCHARGS+=("${!i}")
      fi ;;
  esac
done
STRBENCHARGS=$(printf '"%s" ' "${BENCHARGS[@]}")

if [[ -z "$BENCH" ]]; then
  echo "Error: no benchmark specified"
  exit 1
fi

if [[ "$NIGHT_OR_DAY" == "auto" ]]; then
  h=$(cut -d ':' -f 1 <<<"$WT:0:0")
  m=$(cut -d ':' -f 2 <<<"$WT:0:0")
  s=$(cut -d ':' -f 3 <<<"$WT:0:0")
  deadline=$(date -d "now + $h hours $m minutes $s seconds" +%H)
  if [[ $h -ge 6 || $deadline -ge 19 ]]; then
    NIGHT_OR_DAY="night"
  else
    NIGHT_OR_DAY="day"
  fi
fi

largs="{$SQL_OW}/cluster=1/host=$NB_OW"
if (( $NB_SWIFT > 0 )); then
  largs+="+{$SQL_SWIFT}/host=$NB_SWIFT"
fi

echo "Submitting job..."
oarsub -t "$NIGHT_OR_DAY" -t monitor=wattmetre_power_watt -t deploy -l "$largs,walltime=$WT" -O "logs/deploy_logs.%jobid%.stdout" -E "logs/deploy_logs.%jobid%.stderr" -n "-w $WT -ow $NB_OW -sw $NB_SWIFT -i $ITERATIONS -r $RUNS --$NIGHT_OR_DAY $BENCH $STRBENCHARGS" "./g5k_deploy/benchmarks/$BENCH.sh $NB_OW $NB_SWIFT $ITERATIONS $RUNS $STRBENCHARGS"
echo "  Done. Reproduce with: $0 -w $WT -ow $NB_OW -sw $NB_SWIFT -i $ITERATIONS -r $RUNS --$NIGHT_OR_DAY $BENCH $STRBENCHARGS"
echo "$0 -w $WT -ow $NB_OW -sw $NB_SWIFT -i $ITERATIONS -r $RUNS --$NIGHT_OR_DAY $BENCH $STRBENCHARGS" >>~/.greenfaas_submit_history
