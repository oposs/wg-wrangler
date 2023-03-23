#!/bin/bash
set -ex

DISTRIBUTION_NAME=$1
DISTRIBUTION_VERSION=$2

# Overriding $HOME to prevent permissions issues when running on github actions
mkdir -p /tmp/home
chmod 0777 /tmp/home
export HOME=/tmp/home

dh_clean
dpkg-buildpackage -us -uc -nc

release_number=${DISTRIBUTION_VERSION/\./\_}
package_name=$(basename ../wg-wrangler_*.deb | sed 's/.deb$//')_${DISTRIBUTION_NAME}-${release_number}.deb
mv ../wg-wrangler_*.deb "$package_name"

# set action output
echo "package_name=$package_name" >>$GITHUB_OUTPUT
