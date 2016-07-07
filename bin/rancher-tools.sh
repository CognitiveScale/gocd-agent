#!/bin/bash

function getEnvironmentActionEndpoint() {
  local STACK_NAME="$1"
  local ACTION="$2"
  curl -s -u $RANCHER_API_KEY \
    -H 'Accept: application/json' \
    -H 'Content-Type: application/json' \
    -X GET $RANCHER_URL/v1/projects/1a5/environments | \
    jq -r '.data | map(select(.name=="'"$STACK_NAME"'")) | .[].actions.'"$ACTION"
}