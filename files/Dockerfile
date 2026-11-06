# **************************************************************************
#              Download cache (everything not coming from apt)
# **************************************************************************

# Image steps mount a BuildKit cache (id=dl-cache) on ${P_DL_DIR} (defaulted to "/downloads")
# 'docker-build.hook' syncs it with "persist/downloads"
# NB: BuildKit identifies caches by id AND by uid/gid : all --mount=type=cache options must be exactly the same.
# NB: never use --no-cache on these stages : BuildKit would give them an empty cache.
# Re-run is forced by P_TIMESTAMP.


ARG P_USER_UID=10000
ARG P_USER_GID=10000
ARG P_DL_DIR=/downloads


# **************** target "dl-import" ****************
# "persist/downloads" (named context "dl-context") => BuildKit cache (existing files are kept)
# This stage is built only when requested with --target (default target: "image", the last stage).
FROM ubuntu:22.04 AS dl-import
ARG P_USER_UID
ARG P_USER_GID
ARG P_DL_DIR
ARG P_TIMESTAMP=0
RUN --mount=type=bind,from=dl-context,target=/dl-input \
    --mount=type=cache,id=dl-cache,target=${P_DL_DIR},sharing=locked,uid=${P_USER_UID},gid=${P_USER_GID} \
    cp -a --no-preserve=ownership -n /dl-input/. ${P_DL_DIR}/ && \
    chown -R ${P_USER_UID}:${P_USER_GID} ${P_DL_DIR} && \
    echo "[${P_TIMESTAMP}] Import download cache : $(find ${P_DL_DIR} -type f | wc -l) file(s)"


# **************** stage "dl-collect" ****************
# Copy the BuildKit cache to "/dl-output" (a cache mount cannot be exported directly), without partial files (*.part)
# This stage is built only when requested with --target (default target: "image", the last stage).
FROM ubuntu:22.04 AS dl-collect
ARG P_USER_UID
ARG P_USER_GID
ARG P_DL_DIR
ARG P_TIMESTAMP=0
RUN --mount=type=cache,id=dl-cache,target=${P_DL_DIR},sharing=locked,uid=${P_USER_UID},gid=${P_USER_GID} \
    mkdir -p /dl-output && \
    cp -a ${P_DL_DIR}/. /dl-output/ && \
    find /dl-output -name '*.part' -delete && \
    echo "[${P_TIMESTAMP}] Export download cache : $(find /dl-output -type f | wc -l) file(s)"


# **************** target "dl-export" ****************
# BuildKit cache => "persist/downloads"
# (copy "/dl-output" of "dl-collect" into an empty image, written on the host by docker build --output type=local)
# This stage is built only when requested with --target (default target: "image", the last stage).
FROM scratch AS dl-export
COPY --from=dl-collect /dl-output/ /


# **************************************************************************
#                     Image with Wine and related tools
# **************************************************************************
FROM ubuntu:22.04 AS image

# APT package installation flags
# ******************************
ARG P_APT_UPDATE_FLAGS='--quiet -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false'
ARG P_APT_UPGRADE_FLAGS='--assume-yes'
ARG P_APT_INSTALL_FLAGS='--assume-yes --no-install-recommends --quiet'
ARG P_APT_KEEP_PKGS='false'

# Dedicated *non-root* user: unless other values are given
# as 'docker build' arguments, the end user is 'wine:wine'
# (default: 10000:10000).
# ************************************************************
ARG P_USER_UID=10000
ARG P_USER_GID=10000
ARG P_USER_NAME=wine
ARG P_USER_GROUP=${P_USER_NAME}
ARG P_USER_PASSWD=${P_USER_NAME}
ARG P_USER_HOME=/home/${P_USER_NAME}

# Wine setup configuration
# ************************
ARG P_WINEPREFIX_INIT=/wine/prefix-init
ARG P_WINEPREFIX=/wine/prefix
ARG P_BATCH_DIR=/batch

ENV WINEARCH=win64
ENV WINEPREFIX_INIT=${P_WINEPREFIX_INIT}
ENV WINEPREFIX=${P_WINEPREFIX}
ENV WINEDEBUG=-all

# Fixed winetricks version, for reproducible builds (master commit of
# 2026-08-27: tag 20260125 is older and has no vcrun2026)
ARG P_WINETRICKS_VERSION=f3890f670867b5ffbc3938726db45c0f7d16c8ba
ENV WINETRICKS_LATEST_VERSION_CHECK=disabled

# Keep docker build fully automated
# *********************************
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-c"]

# Package manager setup
# *********************
RUN <<EOF
    [ "${P_APT_KEEP_PKGS}" == 'true' ] && rm -f '/etc/apt/apt.conf.d/docker-clean'
    echo "Binary::apt::APT::Keep-Downloaded-Packages \"${P_APT_KEEP_PKGS}\";" > '/etc/apt/apt.conf.d/keep-cache'
    apt update ${P_APT_UPDATE_FLAGS}
    apt upgrade ${P_APT_UPGRADE_FLAGS}
EOF

RUN apt update && \
    apt install ${P_APT_INSTALL_FLAGS} \
        apt-file \
        apt-src \
        apt-transport-https \
        apt-utils \
        ca-certificates \
        coreutils \
        gnupg \
        gpg \
        openssl

# Base packages
RUN apt update && \
    apt install ${P_APT_INSTALL_FLAGS} \
        locales \
        tzdata

# Set the locale & timezone
# *************************
ENV LC="fr_FR.UTF-8"

RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    sed -i -e 's/# fr_FR.UTF-8 UTF-8/fr_FR.UTF-8 UTF-8/' /etc/locale.gen && \
    echo 'LANG="fr_FR.UTF-8"' > /etc/default/locale && \
    dpkg-reconfigure locales && \
    update-locale LANG=$LC

ENV TZ="Europe/Paris"

RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime && \
    dpkg-reconfigure tzdata

ENV LANG=$LC
ENV LANGUAGE=$LC
ENV LC_ALL=$LC


# Dedicated user account creation
# *******************************
RUN <<EOF
    set -aeu
    PASSWD=$(openssl passwd ${P_USER_PASSWD})
    ADD_GROUPS="sudo,users"
    SHELL="/bin/bash"

    groupadd --gid ${P_USER_GID} \
             --non-unique \
             ${P_USER_GROUP}

    useradd --uid ${P_USER_UID} \
            --gid ${P_USER_GID} \
            --groups "${ADD_GROUPS}" \
            --non-unique \
            --shell ${SHELL} \
            --password "${PASSWD}" \
            ${P_USER_NAME}

    install -d \
            -m700 \
            -o ${P_USER_NAME} \
            -g ${P_USER_GROUP} \
            ${P_USER_HOME}
EOF


# Wine installation
# *****************
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install ${P_APT_INSTALL_FLAGS} \
        binutils \
        ca-certificates \
        cabextract \
        curl \
        dbus \
        dbus-x11 \
        dialog \
        fonts-dejavu-core \
        fonts-liberation \
        gnupg2 \
        jq \
        locales \
        p7zip-full \
        rsync \
        software-properties-common \
        unzip \
        wget \
        winbind \
        x11-utils \
        xauth \
        xvfb \
        xz-utils

# Official WineHQ repository:
# package with 64/32 bits support.
# **********************************************
RUN mkdir -p /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources && \
    apt-get update ${P_APT_UPDATE_FLAGS} && \
    apt-get install ${P_APT_INSTALL_FLAGS} \
        winehq-stable

# Wine needs a machine-id for a correct initialization
RUN dbus-uuidgen > /etc/machine-id


# Downloads with the ${P_DL_DIR} cache (see "fetch-cached.sh" and file header)
# ****************************************************************************
COPY --chmod=755 fetch-cached.sh wine-headless.sh /usr/local/bin/
ARG P_DL_DIR
# W_CACHE: fixed name, read by winetricks for its download cache
# (do not rename)
ARG W_CACHE=${P_DL_DIR}/winetricks


# Winetricks
# **********
RUN --mount=type=cache,id=dl-cache,target=${P_DL_DIR},sharing=locked,uid=${P_USER_UID},gid=${P_USER_GID} <<EOF
    set -aeu -o pipefail
    url="https://raw.githubusercontent.com/Winetricks/winetricks/${P_WINETRICKS_VERSION}/src/winetricks"
    cached=$(fetch-cached.sh "${url}" "winetricks/winetricks-${P_WINETRICKS_VERSION}")
    install -m755 "${cached}" /usr/local/bin/winetricks
    # Next steps run as the dedicated user
    chown -R ${P_USER_UID}:${P_USER_GID} "${P_DL_DIR}"
EOF


# Wine prefix folders, owned by the dedicated user:
# - WINEPREFIX_INIT : reference prefix, built in the image
# - WINEPREFIX      : working prefix, sync'ed at startup by the entrypoint
RUN install -d -m755 \
        -o ${P_USER_UID} -g ${P_USER_GID} \
        "${WINEPREFIX_INIT}" \
        "${WINEPREFIX}"


# *******
# RUNTIME
# *******
# Run at container startup
ARG P_ENTRYPOINT_SCRIPT=entrypoint.sh
ARG P_ENTRYPOINT_DIR=/usr/local/bin
ENV ENTRYPOINT_PATH=${P_ENTRYPOINT_DIR}/${P_ENTRYPOINT_SCRIPT}
COPY ${P_ENTRYPOINT_SCRIPT} ${ENTRYPOINT_PATH}
RUN ln -sf ${ENTRYPOINT_PATH} "/entrypoint.sh"
ENTRYPOINT ["/entrypoint.sh"]
WORKDIR ${P_BATCH_DIR}


# ********************************
# Polishing end-user environment
# ********************************
ENV DEBIAN_FRONTEND=dialog
RUN <<EOF
    set -aeu
    apt clean
EOF
COPY --chown=${P_USER_NAME}:${P_USER_GROUP} devel-files/* devel-files/.[^.]* ${P_USER_HOME}/
USER ${P_USER_NAME}


# *****************************************************
# Creation of the reference Wine prefix (WINEPREFIX_INIT)
# and installation of Windows software
# *****************************************************
# Downloads still come from the ${P_DL_DIR} cache).
# Winetricks verbs download into W_CACHE=${P_DL_DIR}/winetricks.
RUN --mount=type=cache,id=dl-cache,target=${P_DL_DIR},sharing=locked,uid=${P_USER_UID},gid=${P_USER_GID} <<EOF
    set -aeu -o pipefail
    export WINEPREFIX="${WINEPREFIX_INIT}"

    # ======================================================================
    # Prefix initialization, with Wine Mono and Wine Gecko
    # ======================================================================
    # - versions expected by this Wine version are read in appwiz.cpl,
    # - MSI files come from the ${P_DL_DIR}/wine cache,
    # - Mono goes into the Wine cache (~/.cache/wine), used by wineboot,
    # - Gecko (x86_64 then x86) is installed explicitly with msiexec.
    appwiz="$(dirname "$(readlink -f "$(command -v wine)")")/../lib/wine/x86_64-windows/appwiz.cpl"

     mono_version=$(strings -e l "${appwiz}" | grep -oP '^wine-mono-\K[0-9.]+(?=-x86\.msi$)' | head -n1 || true)
    gecko_version=$(strings -e l "${appwiz}" | grep -oP '^wine-gecko-\K[0-9.]+(?=-x86(_64)?\.msi$)' | head -n1 || true)
    if [ -z "${mono_version}" ] || [ -z "${gecko_version}" ]; then
        echo "ERROR: Mono/Gecko versions not found in ${appwiz}"
        exit 1
    fi
    echo "Wine Mono ${mono_version} / Wine Gecko ${gecko_version}"

    base="https://dl.winehq.org/wine"
    mono_msi=$(fetch-cached.sh "${base}/wine-mono/${mono_version}/wine-mono-${mono_version}-x86.msi" \
                                  "wine/wine-mono-${mono_version}-x86.msi")
    gecko_msis=()
    for arch in x86_64 x86; do
        gecko_msis+=("$(fetch-cached.sh "${base}/wine-gecko/${gecko_version}/wine-gecko-${gecko_version}-${arch}.msi" \
                                           "wine/wine-gecko-${gecko_version}-${arch}.msi")")
    done

    cache="${HOME}/.cache/wine"
    mkdir -p "${cache}"
    cp "${mono_msi}" "${cache}/"
    wine-headless.sh wineboot --init
    for msi in "${gecko_msis[@]}"; do
        wine-headless.sh wine msiexec /i "${msi}" /qn
    done
    rm -rf "${cache}"
    test -f "${WINEPREFIX}/system.reg"

    # ======================================================================
    # Drive D: drive_d folder in the prefix, like drive_c
    # ======================================================================
    mkdir -p "${WINEPREFIX}/drive_d"
    ln -sfn ../drive_d "${WINEPREFIX}/dosdevices/d:"

    # ======================================================================
    # Notepad++
    # ======================================================================
    # Latest version at first download, then frozen by the cache : delete the cached file to update.
    name="apps/npp-latest.Installer.x64.exe"
    url=""
    if [ ! -s "${P_DL_DIR}/${name}" ]; then
        url=$(curl -fsSL https://api.github.com/repos/notepad-plus-plus/notepad-plus-plus/releases/latest \
              | jq -r '.assets[].browser_download_url | select(test("Installer\\.x64\\.exe$"))')
    fi
    install=$(fetch-cached.sh "${url}" "${name}")
    wine-headless.sh wine "${install}" /S
    test -f "${WINEPREFIX}/drive_c/Program Files/Notepad++/notepad++.exe"

    # ======================================================================
    # Firefox
    # ======================================================================
    # Latest version at first download, then frozen by the cache : delete the cached file to update.
    url="https://download.mozilla.org/?product=firefox-latest-ssl&os=win64&lang=fr"
    install=$(fetch-cached.sh "${url}" "apps/firefox-latest-win64-fr.exe")
    wine-headless.sh wine "${install}" /S
    test -f "${WINEPREFIX}/drive_c/Program Files/Mozilla Firefox/firefox.exe"

    # ======================================================================
    # Winetricks: Microsoft fonts (corefonts)
    # ======================================================================
    wine-headless.sh winetricks -q corefonts
    wine-headless.sh winetricks list-installed | grep -qx corefonts

    # ======================================================================
    # Winetricks: Visual C++ runtimes (oldest to newest)
    # ======================================================================
    wine-headless.sh winetricks -q vcrun2010 vcrun2013 vcrun2026

    # ======================================================================
    # Winetricks: extra fonts and subpixel smoothing
    # ======================================================================
    # Consolas comes from PowerPointViewer.exe : the winetricks URL leads to a bad file.
    # So the file is pre-loaded into the winetricks cache from a complete capture (same sha256, checked later by winetricks).
    url="https://web.archive.org/web/20170912132139id_/https://download.microsoft.com/download/E/6/7/E675FFFC-2A6D-4AB0-B3EB-27C9F8C8F696/PowerPointViewer.exe"
    fetch-cached.sh "${url}" "winetricks/PowerPointViewer/PowerPointViewer.exe" > /dev/null
    wine-headless.sh winetricks -q consolas tahoma lucida fontsmooth=rgb

    # ======================================================================
    # Winetricks: native Windows components
    # ======================================================================
    wine-headless.sh winetricks -q msxml6 d3dcompiler_47 riched20

    # ======================================================================
    # Winetricks: .NET Desktop Runtime 10 LTS (x86 + x64, with base runtime)
    # ======================================================================
    wine-headless.sh winetricks -q dotnetdesktop10

    # ======================================================================
    # Winetricks: PowerShell 7 LTS (pwsh.exe) + powershell.exe wrapper
    # (system32 + syswow64). Wrapper URLs are "latest" without checksum:
    # frozen at first download by the download cache.
    # ======================================================================
    wine-headless.sh winetricks -q powershell
EOF

# **************************************************
# Finishing and labelling the image
# (keep interesting metadata for further processing)
# **************************************************

ARG P_BUILD_IMAGE_NAME=""
ENV BUILD_IMAGE_NAME=${P_BUILD_IMAGE_NAME}
ARG P_BUILD_DATE="1970-01-01T00:00:00Z"
ENV BUILD_DATE=${P_BUILD_DATE}
ARG P_BUILD_VERSION="1.0"
ENV BUILD_VERSION=${P_BUILD_VERSION}
LABEL org.label-schema.schema-version="1.0"
LABEL org.label-schema.build-date=${P_BUILD_DATE}
LABEL org.label-schema.version=${P_BUILD_VERSION}


# --------------------------------------------------------------------------------
