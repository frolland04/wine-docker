#!/bin/bash

set -aeu -o pipefail

# --------------------------------------------------------------------

function sync_container_dirs()
{
    # From container
    local source_dir=$1
    readonly source_dir

    # Outside
    local target_dir=$2
    readonly target_dir

    # Image used to sync
    local docker_image=$3
    readonly docker_image

    # Sync folder from the container to an empty external folder
    # (temporarily bind mounted in /sync). Skip if external folder has existing files.
    if [ -z "$(ls -A "${target_dir}")" ]; then
        echo "***********************************************************"
        echo "${source_dir} => ${target_dir}"

        readonly bind_target_dir=/sync
        readonly random_id="$(tr -dc a-z0-9 </dev/urandom | head -c 8; echo)"

        docker run \
            --name "sync_${random_id}" \
            --mount type=bind,src="$(realpath "${target_dir}")",dst="${bind_target_dir}" \
            --rm \
            --entrypoint /bin/bash \
            "${docker_image}" \
            -c "rsync -a -h --info=progress2 --no-inc-recursive ${source_dir}/ ${bind_target_dir}/"
    else
        echo "No sync needed."
    fi
    echo "***********************************************************"
    echo ""
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

# Container to be created: mandatory items
if [[ -z "${IMAGE_NAME:-}" ]]; then
    echo "Error: No image name provided! Exiting."
    exit 1
fi
if [[ -z "${CONTAINER_NAME:-}" ]]; then
    readonly random_id="$(tr -dc a-z0-9 </dev/urandom | head -c 8; echo)"
    CONTAINER_NAME="${IMAGE_NAME}-${random_id}"
fi

echo ""
echo "**********************************************************************"
echo "Starting Docker container from '${IMAGE_NAME}': ${CONTAINER_NAME} ..."
echo "**********************************************************************"
echo ""

# Prepare option flags for docker "run" command
RUN_OPTS=(${DOCKER_RUN_OPTS[@]:-""})
echo "[OPTS] ${RUN_OPTS[@]}"

# Prepare arguments to set up bind mounts
BIND_ARGS=()
for ba in "${DOCKER_RUN_BIND_ARGS[@]}"; do
    IFS=':' read -r id val <<< "${ba}"
    echo "[BIND] ${id} => ${val}"
    BIND_ARGS+=("--mount type=bind,src=$(realpath "${id}"),dst=${val}")
    mkdir -p "${id}"
done

# Prepare arguments to pass some environment variables
ENV_ARGS=()
for ea in "${DOCKER_RUN_ENV_ARGS[@]}"; do
    echo "[ENV] ${ea}"
    ENV_ARGS+=("--env ${ea}")
done

# Prepare arguments to give to the entrypoint
RUN_ARGS=(${DOCKER_RUN_ENTRYPOINT_ARGS[@]:-""})
echo "[RUN] ${RUN_ARGS[@]}"

# Initially sync some (empty) bind mounts
for sd in "${DOCKER_SYNC_DIRS[@]}"; do
    IFS=':' read -r outside inside <<< "${sd}"
    echo "[SYNC] ${inside} >>> ${outside}"
    sync_container_dirs "${inside}" "${outside}" "${IMAGE_NAME}"
done

xhost +local:root
docker run \
    --name "${CONTAINER_NAME}" \
    \
    ${RUN_OPTS[@]} \
    \
    ${BIND_ARGS[@]} \
    \
    ${ENV_ARGS[@]} \
    \
    ${IMAGE_NAME} \
    \
    ${RUN_ARGS[@]} \
    $@

echo "************************************************"
echo "Container '${CONTAINER_NAME}' has been released."
echo "************************************************"
echo "FINISHED."
echo ""
cd "${SAVED_DIR}"
