#!/bin/bash

source rancher-tools.sh

function runRemove() {
  # get remove endpoint
  ENDPOINT_REMOVE=$(getEnvironmentActionEndpoint "$STACK_NAME" "remove")

  if [ "$ENDPOINT_REMOVE" = "null" ]; then
    echo "[error] stack ${STACK_NAME} does not exist"
    exit 1
  fi

  # perform remove
  RES=$(curl -s -u $RANCHER_API_KEY \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -X POST -d "$BODY" "$ENDPOINT_REMOVE" 2>&1)

  echo "$RES"
}

function usage() {
  cat <<EOM
    $0 --host <RANCHER_URL>
       --name <STACK_NAME>
       --api_key <API_KEY>
EOM
  exit 1
}

if [ $# -lt 3 ]; then
  usage
fi

STACK_NAME=$(basename "$PWD")
while [ $# -ge 1 ]; do
  key="$1"
  case $key in
    --host)
      RANCHER_URL="$2"
      shift # past argument
      ;;
    --api_key)
      RANCHER_API_KEY="$2"
       shift
      ;;
    --name)
      STACK_NAME="$2"
      shift
      ;;
    *)
      echo "[error] Unkown parameter \"$1\""  # unknown option
      usage
      ;;
  esac
  shift
done

which curl > /dev/null || echo "[error] curl missing"
runRemove