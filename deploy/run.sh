#!/bin/bash

consul-template -config=/consul-template/config.d/gocd-agent.json -once

AGENT_RESOURCES=${AGENT_RESOURCES:-"docker,bash,git,jdk"}
export AGENT_WORK_DIR=${AGENT_WORK_DIR:-"/work"}
#export AGENT_ENVIRONMENTS=${AGENT_ENVIRONMENTS:-"DEV"}
export LOG_DIR=${AGENT_WORK_DIR}/logs

SERVER_BASE=http://${GO_SERVER}:${GO_SERVER_PORT}/go/api

# need to ping server instead
function goping {
	curl --fail --silent ${SERVER_HEADER} ${SERVER_BASE}/agents > /dev/null
}

while true; do goping && break || echo -n .; sleep 5; done

/opt/go-agent/agent.sh &
# wait for the agent to annouce itself..
sleep 10

UUID=$(curl -s -H 'Accept: application/vnd.go.cd.v2+json' ${SERVER_BASE}/agents |\
	 jq -r "._embedded.agents[] | select (.hostname==\"$HOSTNAME\").uuid")
echo "UUID:" ${UUID}

ACTIVATE="{\"resources\":\"${AGENT_RESOURCES}\",\"agent_config_state\":\"Enabled\"}"

curl -i  -H 'Accept: application/vnd.go.cd.v2+json' \
	-H 'Content-Type:application/json' \
	-X PATCH -d ${ACTIVATE} ${SERVER_BASE}/agents/${UUID}

wait
