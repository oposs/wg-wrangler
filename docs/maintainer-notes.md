# Maintainer notes

## Build dependencies

`build-essential`, `libssl-dev` and `zlib1g-dev` are needed because several
perl dependencies are XS modules that get compiled during the build, Net::SSLeay
among them. `libnet-idn-encode-perl` is required from gcc 14 on, which covers
debian 13 and ubuntu 26.04: the CPAN release of Net::IDN::Encode dates from 2018
and no longer compiles there, so the distribution package is used instead.

## Package versions

`make-deb.sh` appends the distribution codename to the package version
(`0.4.1~noble`). The five packages of one release then have distinct file
names on the GitHub release, and `ri-publish-gitea` sends each to the apt
distribution of that codename (`gitea_packages.debian.distributions` in
`.github/repo-infra.json`). The `~` sorts the package below a later plain
version, so an installed 0.4.0 upgrades to 0.4.1~noble.
