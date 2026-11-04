#!/bin/bash
# Build the wg-wrangler .deb for the distribution this runs on.
#
#   ./make-deb.sh [VERSION [OUTDIR]]
#
# VERSION defaults to the content of the VERSION file, OUTDIR to the current
# directory. The package version is VERSION with the codename of the
# distribution appended (0.4.1~noble), so the packages of one release differ in
# name and each sorts below a later release on its own distribution. A
# pre-release such as 0.5.0-rc1 becomes 0.5.0~rc1~noble, which sorts below
# 0.5.0 as it should.
set -euo pipefail

cd "$(dirname "$0")"
version=${1:-$(tr -d '\n' < VERSION)}
outdir=${2:-$PWD}

. /etc/os-release
codename=${VERSION_CODENAME:?/etc/os-release names no VERSION_CODENAME}
debversion="${version//-/\~}~${codename}"
maintainer=$(sed -n 's/^Maintainer: *//p' debian/control)

# debian/changelog only carries the version; CHANGES.md is the changelog.
cat > debian/changelog <<EOF
wg-wrangler (${debversion}) ${codename}; urgency=medium

  * Release ${version}. The changes are listed in CHANGES.md at
    https://github.com/oposs/wg-wrangler/blob/v${version}/CHANGES.md

 -- ${maintainer}  $(date -R)
EOF

# A HOME the build can write to; the default one in a GitHub Actions
# container belongs to another user.
export HOME=$(mktemp -d)

dh_clean
dpkg-buildpackage -us -uc -nc

mkdir -p "$outdir"
mv ../wg-wrangler_"${debversion}"_*.deb "$outdir"/
ls -l "$outdir"
