#!/usr/bin/env bash

set -e

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 CONTAINER_IMAGE_LOADER CONTAINER_IMAGE_NAME" >&2
  exit 1
fi

# check if we are running inside a Docker container, and skip this test if so.
if [[ -n "$(docker info 2>/dev/null| grep 'Cannot connect')" ]]; then
  echo "No Docker runtime detected, skipping tests."
  exit 0
else
  CONTAINER_IMAGE_LOADER="$1"
  CONTAINER_IMAGE_NAME="$2"

  if [[ -n $(command -v ${CONTAINER_IMAGE_LOADER}) ]] ; then
    ${CONTAINER_IMAGE_LOADER}
    docker run "${CONTAINER_IMAGE_NAME}"
  else
    echo "Command ${CONTAINER_IMAGE_LOADER} is invalid."
    exit 2
  fi
fi


