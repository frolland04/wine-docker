#!/bin/bash

set -aeu -o pipefail

# --------------------------------------------------------------------

function check_exists()
{
    declare -F "$1" >/dev/null
}

# --------------------------------------------------------------------

readonly SCRIPT_FILE="$(readlink -f "$0")"
readonly SCRIPT_NAME="$(basename "${SCRIPT_FILE}")"
readonly SCRIPT_DIR="$(dirname "${SCRIPT_FILE}")"
readonly SAVED_DIR="${PWD}"
cd "${SCRIPT_DIR}"

# Load external configuration files
readonly ENV_FILE="docker.env"
[ -f "${ENV_FILE}" ] && echo "loading ${ENV_FILE} ..." && . "${ENV_FILE}"

readonly HOOK_FILE=${SCRIPT_NAME%.sh}.hook
[ -f "${HOOK_FILE}" ] && echo "loading ${HOOK_FILE} ..." && . "${HOOK_FILE}"

# Image to be created: mandatory items
if [[ -z "${IMAGE_NAME:-}" ]]; then
    echo "Error: No image name provided! Exiting."
    exit 1
fi
if [[ -z "${IMAGE_VERSION+x}" ]]; then
    IMAGE_VERSION="0"
fi

echo "**************************************************"
echo "                    STARTING                      "
echo "     Building Docker image \"${IMAGE_NAME}\"      "
echo "  from ${SCRIPT_DIR} ...                          "
echo "**************************************************"

# Setup custom arguments
BUILD_ARGS=()
for token in ${DOCKER_BUILD_ARGS[@]:-}; do
    echo "[ARG] ${token}"
    BUILD_ARGS+=(--build-arg "${token}")
done

# Setup custom option flags
BUILD_OPTS=(${DOCKER_BUILD_OPTS[@]:=""})
echo "[OPTS] ${BUILD_OPTS[@]}"

readonly TS="$(date --universal +'%Y-%m-%dT%H:%M:%SZ')"
echo "[BUILD] Image timestamp ${TS}"

# Step 1. Custom pre-build actions (optional, defined in the hook file)
# ********************************************************************
check_exists build_hook && \
             build_hook

# Step 2. Build the main image
# ****************************
docker build \
    --build-arg P_BUILD_IMAGE_NAME="${IMAGE_NAME}" \
    --build-arg P_BUILD_DATE="${TS}" \
    --build-arg P_BUILD_VERSION="${IMAGE_VERSION}" \
    \
    "${BUILD_OPTS[@]}" \
    "${BUILD_ARGS[@]}" \
    \
    --tag "${IMAGE_NAME}" \
    ./files

# Step 3. Custom post-build actions (optional, defined in the hook file)
# *********************************************************************
check_exists build_hook_post && \
             build_hook_post

echo "**************************************************"
echo "                    FINISHED!                     "
echo "     Building Docker image \"${IMAGE_NAME}\"      "
echo "  from ${SCRIPT_DIR}                              "
echo "**************************************************"
cd "${SAVED_DIR}"
