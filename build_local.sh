#!/bin/bash

# Overriding $HOME to prevent permissions issues when running on github actions
mkdir -p /tmp/home
chmod 0777 /tmp/home
export HOME=/tmp/home

apt -y update && \
    apt-get -y install apt-utils curl && \
    curl https://deb.nodesource.com/setup_18.x | bash && \
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

dh_clean
dpkg-buildpackage -us -uc -nc

# set filename
release_code_name=$(lsb_release --codename | sed 's/Codename:\s*//')
package_name=$(basename ../*.deb | sed 's/.deb$//')_$release_code_name.deb
mv ../*.deb ../$package_name

