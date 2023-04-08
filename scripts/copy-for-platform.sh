#!/bin/bash

set -e

TEMP_DIR=$(mktemp -d)
trap 'test -d "${TEMP_DIR}" && rm -rf "${TEMP_DIR}"' EXIT

skopeo copy docker://ghcr.io/hankei6km/test-oras-oras-cll-os-arch/multi_platforms:1 dir:"${TEMP_DIR}"
cat "${TEMP_DIR}/$(jq -r '.layers[0].digest' < "${TEMP_DIR}/manifest.json" | cut -d ':' -f 2)"
