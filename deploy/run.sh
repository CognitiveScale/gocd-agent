#!/bin/bash
CERTS_DIR=/cscerts
setup_certs() {
  if [ -f "${CERTS_DIR}/ca.cert.pem" ]; then
    cp ${CERTS_DIR}/*.cert.pem /usr/local/share/ca-certificates
    update-ca-certificates
  else
    echo "${CERTS_DIR} NOT FOUND certificates not installed to /etc/ssl !!!"
  fi
}
setup_certs_java() {
  if [ -f "${CERTS_DIR}/ca-chain.cert.pem" ]; then
  keytool -import \
    -storepass changeit -noprompt \
    -keystore /usr/lib/jvm/default-jvm/jre/lib/security/cacerts \
    --alias cs_key_chain -file ${CERTS_DIR}/ca-chain.cert.pem
  else
    echo "${CERTS_DIR}/ca-chain.cert.pem NOT FOUND certificates not installed !!!"
  fi
}
get_certs_vault() {
    curl -H "X-Vault-Token: $VAULT_TOKEN" -X POST \
    -d "{\"common_name\":\"neo4j\",\"alt_names\":\"neo4j.service.consul,$HOSTNAME\",\"ip_sans\":\"127.0.0.1\",\"format\":\"pem\"}" \
    ${VAULT_ADDR}/v1/pki/issue/c12e-dot-local  > /tmp/certs.json
    mkdir -p  /opt/neo4j/conf/ssl
    jq -r .data.private_key /tmp/certs.json | openssl rsa  -inform PEM -outform DER > /opt/neo4j/conf/ssl/snakeoil.key
    jq -r .data.certificate /tmp/certs.json > /opt/neo4j/conf/ssl/snakeoil.cert
    rm /tmp/certs.json
}
get_secrets() {
    cd /
    curl -H "X-Vault-Token: $VAULT_TOKEN" -X GET \
    ${VAULT_ADDR}/v1/secret/gocd\
      | jq -r .data.rootfs\
      | base64 -d\
      | tar xz
    [ ! -f /root/.ssh/known_host ] && ssh-keyscan github.com >> /root/.ssh/known_hosts
}
wait_for() {
  local proto="$(echo $1 | grep :// | sed -e's,^\(.*://\).*,\1,g')"
  local url="$(echo ${1/$proto/})"
  local user="$(echo $url | grep @ | cut -d@ -f1)"
  host_port="$(echo ${url/$user@/} | cut -d/ -f1)"
  host=$(echo $host_port | cut -d: -f1)
  port=$(echo $host_port | cut -d: -f2)
  echo "Waiting for ${host} on ${port}"
  while ! nc -z ${host} ${port}; do
    sleep 1
    echo -n "."
  done
}
wait_for $VAULT_ADDR
if [ ! -z "${VAULT_ADDR}" ]; then
  echo "Installing keys from ${CERTS_DIR} to /etc/ssl"
  setup_certs

  echo "Installing keys from ${CERTS_DIR} to java"
  setup_certs_java

  get_secrets
fi

AGENT_RESOURCES=${AGENT_RESOURCES:-"docker,bash,git,jdk"}
export AGENT_WORK_DIR=${AGENT_WORK_DIR:-"/work"}
#export AGENT_ENVIRONMENTS=${AGENT_ENVIRONMENTS:-"DEV"}
export LOG_DIR=${AGENT_WORK_DIR}/logs
export GO_SERVER_PORT=8153
export GO_SERVER=go-server

SERVER_BASE=http://${GO_SERVER}:8153/go/api

wait_for $SERVER_BASE
[ -f /work/.agent-bootstrapper.running ] &&  rm -f /work/.agent-bootstrapper.running

/opt/go-agent/agent.sh &

# wait for the agent to annouce itself..
sleep 10
PASS="admin:badger"
UUID=$(curl -s -u $PASS -H 'Accept: application/vnd.go.cd.v2+json' ${SERVER_BASE}/agents |\
	 jq -r "._embedded.agents[] | select (.hostname==\"$HOSTNAME\").uuid")
echo "UUID:" ${UUID}

ACTIVATE="{\"resources\":\"${AGENT_RESOURCES}\",\"agent_config_state\":\"Enabled\",\"envrionments\":[\"Dev\"]}"

curl -i  -u $PASS -H 'Accept: application/vnd.go.cd.v2+json' \
	-H 'Content-Type:application/json' \
	-X PATCH -d ${ACTIVATE} ${SERVER_BASE}/agents/${UUID}

wait
