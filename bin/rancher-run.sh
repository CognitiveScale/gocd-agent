#!/bin/bash -ue
function enc() {
   awk '{printf "%s\\n",$0} END {print ""}' $1
}
function runCompose() {
  TST=$(enc $DOCKER_COMPOSE)
  BODY="{\"dockerCompose\":\"$(enc $DOCKER_COMPOSE)\","
  BODY+="\"name\":\"$STACK_NAME\","
  [[ ! -z "$RANCHER_COMPOSE" ]] && BODY+=\"rancherCompose\":\"$(enc $RANCHER_COMPOSE)\",
  if [ ! -z "$ENVIRONMENT" ]; then
    echo $ENVIRONMENT
    len=$(echo $ENVIRONMENT| tr ' ' '\n' | wc -l)
    BODY+="\"environment\":{"
    var=1
    echo $len
    for E in $ENVIRONMENT; do
      BODY+="\"${E%=*}\":\"${E#*=}\""
      [ $var -lt $len ] && BODY+=","
      ((var++))
    done
    BODY+="},"
  fi
  BODY+="\"startOnCreate\": true,"
  BODY+="\"description\"":"\"Description\""
  BODY+="}"
  echo $BODY
  RES=$(curl -s -u $RANCHER_API_KEY \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -X POST -d "$BODY" $RANCHER_URL/v1/environment 2>&1)
   echo $RES
}

function usage() {
  cat <<EOM
    $0 --host <RANCHER_URL>
      --name <STACK_NAME>
      --api_key <API_KEY>
      --docker_compose <DOCKER_COMPOSE>
      --rancher_compose <RANCHER_COMPOSE>
      --env KEY=value
EOM
  exit 1
}
if [ $# -lt 3 ]; then
      usage
fi

RANCHER_COMPOSE=""
DOCKER_COMPOSE=""
ENVIRONMENT=""
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
        --docker_compose)
            DOCKER_COMPOSE="$2"
            if [ ! -f $DOCKER_COMPOSE ]; then
                echo "[ERROR] docker-compose: $DOCKER_COMPOSE doesn't exist"
                exit 1
            fi
            shift
        ;;
        --rancher_compose)
            RANCHER_COMPOSE="$2"
            if [ ! -f $RANCHER_COMPOSE ]; then
                echo "[ERROR] rancher-compose: $RANCHER_COMPOSE doesn't exist"
                exit 1
            fi
            shift
        ;;
        --name)
          STACK_NAME="$2"
          shift
        ;;
        --env)
          ENVIRONMENT+=" $2"
          shift
        ;;
        *)
          echo "[ERROR] Unkown parameter \"$1\""    # unknown option
          usage
       ;;
    esac
    shift
done
which curl > /dev/null || echo "[error] curl missing"
runCompose
