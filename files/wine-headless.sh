#!/bin/bash
#
# wine-headless.sh <command> [args...]
#
# Run <command> (wine, wineboot, winetricks...) on a virtual X server (Xvfb).
# Then wait for the end of all Wine processes of the prefix (wineserver -w)
# BEFORE stopping the X server: no more "X connection to :99 broken" messages.
# Return the exit code of <command>.
#
# xvfb-run is not used: it detects the Xvfb startup with SIGUSR1, and a race
# condition can block it forever. Here, Xvfb selects a free display itself
# and writes it (-displayfd) when ready.

set -u -o pipefail

if (( $# == 0 )); then
    echo "Usage: $(basename "$0") <command> [args...]" >&2
    exit 2
fi

# A wineserver still running (started just before WITHOUT display, for example
# by "winetricks list-installed") forces its "no graphics driver" state on this
# session: windows fail ("no driver could be loaded").
# So wait for its end before starting Xvfb.
wineserver -w

readonly XVFB_TIMEOUT=30
workdir="$(mktemp -d)"
displayfile="${workdir}/display"
: > "${displayfile}"
xvfb_pid=""

cleanup()
{
    if [ -n "${xvfb_pid}" ]; then
        kill "${xvfb_pid}" 2>/dev/null
        wait "${xvfb_pid}" 2>/dev/null
    fi
    rm -rf "${workdir}"
}
trap cleanup EXIT

# Start Xvfb: it writes the display number on fd 3 when ready
Xvfb -displayfd 3 -screen 0 1280x1024x24 -nolisten tcp 3>"${displayfile}" 2>"${workdir}/xvfb.log" &
xvfb_pid=$!

for (( i = 0; i < XVFB_TIMEOUT * 10; i++ )); do
    [ -s "${displayfile}" ] && break
    if ! kill -0 "${xvfb_pid}" 2>/dev/null; then
        echo "ERROR: Xvfb stopped during startup:" >&2
        cat "${workdir}/xvfb.log" >&2
        xvfb_pid=""
        exit 1
    fi
    sleep 0.1
done
if [ ! -s "${displayfile}" ]; then
    echo "ERROR: Xvfb not ready after ${XVFB_TIMEOUT}s" >&2
    exit 1
fi

export DISPLAY=":$(tr -dc '0-9' < "${displayfile}")"

"$@"
rc=$?
wineserver -w
exit ${rc}
