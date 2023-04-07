#!/bin/bash

set -e

TEMP_DIR=$(mktemp -d)
trap 'test -d "${TEMP_DIR}" && rm -rf "${TEMP_DIR}"' EXIT

docker pull ghcr.io/oras-project/oras:v1.0.0

docker save ghcr.io/oras-project/oras:v1.0.0 \
    | tar -xOf- --wildcards "*.tar" \
    | tar -ixf - -C "${TEMP_DIR}" "bin/oras" 

LOCAL_BIN="${HOME}/.local/bin"
test ! -d "${LOCAL_BIN}" && mkdir -p "${LOCAL_BIN}"
cp "${TEMP_DIR}/bin/oras" "${LOCAL_BIN}/oras"