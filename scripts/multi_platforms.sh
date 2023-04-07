#!/bin/bash

set -e

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORAS_CLI="${HOME}/.local/bin/oras"

USER="${GITHUB_ACTOR}"

PKG_NAME="multi_platforms"

REGISTRY="ghcr.io"
REGISTRY_CONFIG="$(mktemp)"
trap 'test -f "${REGISTRY_CONFIG}" && rm -f "${REGISTRY_CONFIG}"' EXIT

ANNOTATION="$(envsubst '${GITHUB_REPOSITORY}' < "${BASE_DIR}/envsubst_annotation.txt")"

function push_artifact {
  # oras push で絶対 PATH を相対 PATH にする方法は?
  pushd "${1}/${2}" > /dev/null || return
  trap 'popd > /dev/null' RETURN

  local TEMP_MANIFEST
  TEMP_MANIFEST="$(mktemp)"
  "${ORAS_CLI}" push --export-manifest "${TEMP_MANIFEST}" \
      "ghcr.io/${GITHUB_REPOSITORY}/${PKG_NAME}:${1}_${2}" \
      ./TEST.md:application/markdown \
      --annotation-file <(echo "${ANNOTATION}") \
      --registry-config "${REGISTRY_CONFIG}" \
    | grep -e "^Digest: " \
    | cut -d " " -f 2
  wc -c "${TEMP_MANIFEST}" | cut -d " "  -f 1
}

function push_and_make_manifest {
  local DIGEST_SIZE DLM

  cat <<'EOF'
  {
    "mediaType": "application/vnd.oci.image.index.v1+json",
    "schemaVersion": 2,
    "manifests": [
EOF

  DLM=""
  for PLATFORM in "linux/arm" "linux/arm64" "linux/amd64" "darwin/arm64" "darwin/amd64" ; do
    OS="$(dirname "${PLATFORM}")"
    ARCH="$(basename "${PLATFORM}")"
    DIGEST_SIZE="$(push_artifact "${OS}" "${ARCH}")"
    cat <<EOF
      ${DLM}{
        "mediaType": "application/vnd.oci.image.manifest.v1+json",
        "digest": "$(echo "${DIGEST_SIZE}" | head -n1)",
        "size": $(echo "${DIGEST_SIZE}" | tail -n1),
        "platform": {
          "architecture": "${ARCH}",
          "os": "${OS}"
        }
      }
EOF
  DLM=","
  done

  cat <<EOF
    ],
    "annotations": {
      "org.opencontainers.image.source": "https://github.com/${GITHUB_REPOSITORY}"
    }
  }
EOF
}

# Login to ghcr.io
envsubst < "${BASE_DIR}/envsubst_token.txt" \
  | "${ORAS_CLI}" login "${REGISTRY}" --username "${USER}" --password-stdin --registry-config "${REGISTRY_CONFIG}"

push_and_make_manifest | jq -r | "${ORAS_CLI}" manifest push \
  "ghcr.io/${GITHUB_REPOSITORY}/${PKG_NAME}:1" \
  --registry-config "${REGISTRY_CONFIG}" -