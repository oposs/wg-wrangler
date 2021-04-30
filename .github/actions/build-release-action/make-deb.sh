#!/bin/sh
set -ex
cd /github/workspace/
dh_clean
dpkg-buildpackage -us -uc -nc
release_code_name=$(lsb_release --codename | sed 's/Codename:\s*//')
package_name=$(basename ../*.deb | sed 's/.deb$//')_$release_code_name.deb

mv ../*.deb $package_name
echo "::set-output name=package_name::$package_name"
