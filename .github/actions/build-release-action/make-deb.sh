#!/bin/sh
set -ex
cd /github/workspace/

# workaround for debhelper bug: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=897569
mkdir -p deb_build_home
ls | grep -v deb_build_home | xargs mv -t deb_build_home # move everything except deb_build_home
cd deb_build_home

dh_clean
dpkg-buildpackage -us -uc -nc

# set filename
release_code_name=$(lsb_release --codename | sed 's/Codename:\s*//')
package_name=$(basename ../*.deb | sed 's/.deb$//')_$release_code_name.deb
mv ../*.deb ../$package_name

# set action output
echo "::set-output name=package_name::$package_name"