#!/bin/bash

echo "************"
echo "[ENTRYPOINT]"
echo "************"

echo "[UID] $(id -u)"
echo "[GID] $(id -g)"

set -aeu -o pipefail

if (( $# == 0 )); then
    echo "ERROR: You have to provide the full path of the .BAT to launch!"
    echo "Aborting."
    exit 1
fi

BAT_SCRIPT="$1"
shift 1

if [ ! -f "${BAT_SCRIPT}" ]; then
    echo "ERROR: Given file \"${BAT_SCRIPT}\" cannot be found!"
    echo "Aborting."
    exit 1
fi

# Sync the working Wine prefix (WINEPREFIX) from the reference prefix
# built in the image (WINEPREFIX_INIT), at first start
# (prefix missing or not initialized).
if [ ! -f "${WINEPREFIX}/system.reg" ]; then
    echo ""
    echo "*******************************************************************"
    echo "Sync the Wine prefix folder ${WINEPREFIX_INIT} => ${WINEPREFIX} ..."
    echo "*******************************************************************"
    echo ""
    mkdir -p "${WINEPREFIX}"
    # Minimal progress: one global line (no file list).
    # --no-inc-recursive: file count known at start, so the % is exact.
    rsync -a -h --info=progress2 --no-inc-recursive "${WINEPREFIX_INIT}/" "${WINEPREFIX}/"
    echo ""
fi

echo ""
echo "****************************************"
echo "Launch \"${BAT_SCRIPT}\" using Wine ..."
echo "****************************************"
echo ""

echo "[BAT] \"${BAT_SCRIPT}\""
echo "[ARGS] \"$*\""

wine cmd /c "${BAT_SCRIPT}" "$@"
