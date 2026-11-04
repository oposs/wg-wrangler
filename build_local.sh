#!/bin/bash
# Build the .deb for the distribution of the container this runs in, the same
# way the release build does. From the source tree:
#
#   podman run --rm -v $(pwd):/mnt -it ubuntu:24.04 /mnt/build_local.sh
#
# The package lands in the source tree. Node 20 or newer must be available;
# on distributions that ship an older one, this installs node 22 from
# nodesource.
set -euo pipefail

apt-get update
apt-get install -y git build-essential debhelper autoconf automake perl curl \
    ca-certificates openssl pkg-config gettext libssl-dev zlib1g-dev \
    libqrencode-dev libnet-idn-encode-perl nodejs npm
case "$(node --version 2>/dev/null)" in
    v2[0-9]*) ;;
    *) curl -fsSL https://deb.nodesource.com/setup_22.x | bash
       apt-get install -y nodejs ;;
esac

# Build in a copy of the tracked and new files only, so the host tree stays
# clean and its own configure output (config.status, Makefiles) stays out.
git config --global --add safe.directory /mnt
rm -rf /src
mkdir /src
git -C /mnt ls-files -z --cached --others --exclude-standard \
    | tar -C /mnt --null -T - -cf - | tar -C /src -xf -
export DEB_BUILD_OPTIONS="parallel=${PARALLEL:-4}"
/src/make-deb.sh "$(tr -d '\n' < /src/VERSION)" /mnt
