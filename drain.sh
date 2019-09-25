#!/usr/bin/env bash

set -e

DRY_RUN="false"
NODEPOOLS=""
SCALE_FILE=""

for i in "$@"
do
case $i in
    --dry-run)
    DRY_RUN="true"
    ;;
    --nodepools=*)
    NODEPOOLS="${i#*=}"
    ;;
    --scale-file=*)
    SCALE_FILE="${i#*=}"
    ;;
    *)
    log "ERROR: unknown parameter \"$i\""
    exit 1
    ;;
esac
done

IFS=',' read -r -a discovered_pools <<< "${NODEPOOLS}"
nodes=()
for pool in "${discovered_pools[@]}"; do
  curr_nodes=$(kubectl get no -l "cloud.google.com/gke-nodepool=${pool}" -o json | jq '.items[].metadata.name' -r | xargs)
  nodes+=( $curr_nodes )
  echo "-> Cordon \"${pool}\" node pool"
  cordon_cmd="kubectl cordon -l \"cloud.google.com/gke-nodepool=${pool}\""
  if [[ $DRY_RUN == "true" ]]; then
    echo "-> would run: $cordon_cmd"
  else
    eval $cordon_cmd
  fi
done

echo "----> Start scaling up defined resources.."

if [[ $SCALE_FILE != "" ]]; then
 lines=`cat $SCALE_FILE`
 for line in $lines; do
     IFS=',' read -r -a resource <<< "${line}"
     type=${resource[0]}
     namespace=${resource[1]}
     name=${resource[2]}
     replicas=$(kubectl -n ${namespace} get ${type} -o json ${name} | jq -r '.status.replicas')
     new_replicas_value=$((replicas*2))
     cmd="kubectl -n ${namespace} scale ${type} --replicas=${new_replicas_value} ${name}"
     if [[ $DRY_RUN == "true" ]]; then
       echo "-> would run: $cmd"
     else
       eval $cmd
     fi
 done
fi

echo "----> Start draining nodes.."

rm -f run.sh
for node in ${nodes[@]}; do
  echo "-> drain \"${node}\" node"
  drain_cmd="kubectl drain --force --ignore-daemonsets --delete-local-data ${node}"
  if [[ $DRY_RUN == "true" ]]; then
    echo "-> would run: $drain_cmd"
  else
    echo "$drain_cmd" >> run.sh
  fi
done
if [[ $DRY_RUN == "false" ]]; then
  chmod +x run.sh
  cat run.sh | parallel
fi
echo "----> done"

echo "----> Start scaling down defined resources.."

if [[ $SCALE_FILE != "" ]]; then
 lines=`cat $SCALE_FILE`
 for line in $lines; do
     IFS=',' read -r -a resource <<< "${line}"
     type=${resource[0]}
     namespace=${resource[1]}
     name=${resource[2]}
     replicas=$(kubectl -n ${namespace} get ${type} -o json ${name} | jq -r '.status.replicas')
     new_replicas_value=$((replicas/2))
     cmd="kubectl -n ${namespace} scale ${type} --replicas=${new_replicas_value} ${name}"
     if [[ $DRY_RUN == "true" ]]; then
       echo "-> would run: $cmd"
     else
       eval $cmd
     fi
 done
fi
