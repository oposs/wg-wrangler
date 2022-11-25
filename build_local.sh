#!/bin/bash

apt -y update && \
    apt-get -y install apt-utils curl && \
    curl https://deb.nodesource.com/setup_16.x | bash && \
    apt-get -u update && \
    apt-get -y install perl \
        make \
        gcc \
        devscripts \
        openssl \
        pkg-config \
        libssl-dev \
        debhelper \
        automake \
        nodejs \
        libkrb5-dev \
        libqrencode-dev \
        g++ \
        zlib1g-dev
        
# copy entire source tree
mkdir /src
cp -r . /src

cd /src

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

