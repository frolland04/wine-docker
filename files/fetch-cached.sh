#!/bin/bash
#
# fetch-cached.sh <url> <relative path>
#
# Download <url> into the download cache (${P_DL_DIR}, default /downloads),
# as <relative path>. Skip the download if the file is already there
# (and not empty). Print the absolute path of the cached file on stdout.

set -eu -o pipefail

if (( $# != 2 )); then
    echo "Usage: $(basename "$0") <url> <relative path in cache>" >&2
    exit 2
fi

url="$1"
target="${P_DL_DIR:-/downloads}/$2"

if [ -s "${target}" ]; then
    echo "[CACHE] ${target}" >&2
else
    echo "Downloading ${url} => ${target}" >&2
    mkdir -p "$(dirname "${target}")"
    tmp="$(mktemp "${target}.XXXXXX.part")"
    trap 'rm -f "${tmp}"' EXIT
    curl -fsSL -o "${tmp}" "${url}"
    chmod 644 "${tmp}"
    mv -f "${tmp}" "${target}"
    trap - EXIT
fi

echo "${target}"
