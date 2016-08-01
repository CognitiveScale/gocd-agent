#!/bin/bash -eu
set_globals() {
    USER=""
    PASS=""
}
## emulate a hash map... using variable
function hput() {
    eval "$1""$2"='$3'
}

function hget() {
    eval echo '${'"$1$2"'#hash}'
}

getdval() {
 local TMP=$(grep -m1 "$1" <<< "$2")
 echo ${TMP} | sed -e "s/^[^:]*:\(.*\)/\1/" -e "s/\"//g" -e "s/,//g"
}

dump_pipe_versions() {
    echo "#Platform-test on: $(date -u +%FT%TZ)"
    "${GO_DEPENDENCY_LOCATOR:?Need to set GO_DEPENDENCY_LOCATOR non-empty}"
    for K in ${!GO_DEPENDENCY_LOCATOR*}; do
        PJOB=${!K}
        RPT="$(curl -s --insecure -u "$USER:$PASS" ${GO_SERVER_URL}/go/files/${PJOB}/Build/reports/buildReport.json)"
        DOCKER_TAG=$(getdval docker_tag "$RPT")
        SERVICE_NAME=$(getdval name "$RPT")
        TIMESTAMP=$(getdval timestamp "$RPT")
        echo ""
        echo "#$SERVICE_NAME built on: $TIMESTAMP"
        echo "$SERVICE_NAME:"
        echo "  image: $DOCKER_TAG"
    done
}

dump_images_versions() {
  "${IMAGES:?Need to set IMAGES non-empty}"
  for var in ${!IMAGES@}; do
    echo ""
    echo "${var#IMAGES}:"
    echo "  image: ${!var}"
  done
}

wait_for() {
  local proto="$(echo "$1" | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  local url="${1/$proto/}"
  local user="$(echo "$url" | grep @ | cut -d@ -f1)"
  local host_port="$(echo "${url/$user@/}" | cut -d/ -f1)"
  local host=${host_port%:*}
  local port="80"
  [[ ${host_port} == *":"* ]] && port=${host_port#*:}
  echo "Waiting for ${host} on ${port}"
  VAL=1
  MAXWAIT=20
  while ! nc -z "${host}" "${port}" &> /dev/null; do
    sleep ${VAL}
    echo -n "$VAL"
    VAL=$((VAL+2))
    if [ ${VAL} -gt ${MAXWAIT} ]; then
                echo "Waited for 20 seconds, no response exiting"
                exit 1
    fi
  done
}

usage() {
  echo "$0 --user <GO USER> --pass <GO PASS> [--image <service>:<image>]*"
  exit 1
}
set_globals

[ $# -lt 4 ] && usage

while [ $# -ge 1 ]; do
key="$1"

case ${key} in
    --user)
        USER="$2"
        shift
    ;;
    --pass)
        PASS="$2"
        shift # past argument
    ;;
    --image)
       IMG="$(echo $2 | sed -e "s/^[^:]*:\(.*\)/\1/" -e "s/\"//g" -e "s/,//g")"
       SN="$(echo $2 | cut -d':' -f1)"
       hput IMAGES "${SN}" "${IMG}"
       shift
    ;;
    --host)
        GO_SERVER_URL="$2"
        shift
    ;;
    *)
          echo "Unknown parameter \"$1\""    # unknown option
          usage
      ;;
esac
shift # past argument or value
done
wait_for ${GO_SERVER_URL}
dump_pipe_versions
dump_images_versions
