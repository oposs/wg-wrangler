# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
except that the first subsection is called `New` rather than `Added`. The release
workflow matches on `### New`; renaming it silently drops the section from the
release notes.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### New

- The .deb packages are published in the apt repository at gitea.oetiker.ch, one distribution per codename (bookworm, trixie, jammy, noble, resolute). The README shows the commands to add it.

### Changed

- The package file names carry the distribution codename, for example `wg-wrangler_0.4.1~noble_amd64.deb`, instead of a suffix such as `_ubuntu-24_04.deb`. The package version carries it as well.
- `./configure` builds and tests in a container by default. To build and install from source on the host, run `./configure --disable-container`.
- The test target is `make check`; `make test` no longer exists.
- wg-wrangler is licensed under the GPL-3.0. The LICENSE file used to hold only placeholder text.

### Fixed

## 0.4.0 - 2026-08-10

Identical to 0.4.0~rc4. The entries below carry the detail; the headlines since 0.3.1 are:

- Build targets are ubuntu 22.04, 24.04, 26.04, debian 12 and 13. All five are now also covered by the test suite, which used to run on two of them
- Requires node 20 or newer and perl 5.34 or newer. configure used to accept perl 5.22 and silently skipped the frontend build on any node above 18
- qooxdoo updated to 7.9.3, Net::IP replaced by the maintained Net::IP::XS
- Two behaviour changes worth noting before upgrading: address validation now rejects input it used to accept, and 'Allowed IPs' is a required field for the first time. A typo there used to end up verbatim in the client configuration mailed to the peer
- The maintainer scripts no longer fail when the wg-wrangler_manager account already exists as a regular user, and postrm no longer reverts permissions on every upgrade
- Test suite grew from 36 to 96 tests

## 0.4.0-rc4 - 2026-08-08

- Removed the name attributes from the action config of WireguardShow. Every start logged "action should not have a name attribute" once per worker. CallBackery overwrites the name of a popup action right after warning about it, so the attributes were never used for anything

## 0.4.0-rc3 - 2026-08-07

- Fixed the maintainer scripts. postinst aborted when an account named wg-wrangler_manager already existed as a regular user, left the .gitconfig unwritten because the home directory was never created, and still exited 0, so dpkg considered the half configured package installed
- postrm no longer runs on upgrade. It used to revert the group of /etc/wireguard, drop the sudoers rule and try to delete the account on every upgrade, relying on the incoming postinst to restore all of it
- The sudoers rule is written instead of appended and gets mode 0440
- Documented which account and home directory the package uses, and how to point an existing account at it. git reads the home directory from /etc/passwd, so a .gitconfig written elsewhere is never seen

## 0.4.0-rc2 - 2026-08-06

- configure requires perl 5.34 instead of 5.22. Nothing below 5.34 was built or tested, 5.34 on ubuntu 22.04 is the oldest of the five build targets
- Replaced debian/compat with debhelper-compat in Build-Depends. The file was itself deprecated and produced 74 warnings per package build
- Added tests for WireguardDataAdapter, which had no coverage although it hosts the validator dispatch behind every peer form field. The suite is now at 96 tests

## 0.4.0-rc1 - 2026-08-06

- Debian packages are built again, for debian 12 and 13 alongside ubuntu 24.04 and 26.04
- Replaced Net::IP, unmaintained since 2012, with Net::IP::XS
- looks_like_ip() now actually validates. It discarded the parse result and accepted everything, so a typo in 'Allowed IPs' or 'DNS' went straight into the client configuration mailed to the peer. Empty values are rejected as well, which is what makes the required flag on 'allowed-ips' take effect for the first time
- Added tests for the IPManager validation and error paths, raising branch coverage of that module from 40% to 81%

## 0.4.0-beta - 2026-08-05

- Build targets are now ubuntu 24.04 and 26.04; the dead debian 10/11 and ubuntu 18.04/20.04 targets are gone
- configure now accepts node 20 through 26 and requires at least 20. Before this it silently skipped the frontend build on anything newer than node 18
- qooxdoo updated to 7.9.3
- debhelper compat raised from the deprecated 9 to 13
- GitHub actions updated; the unit test matrix had exclude rules that stopped it from ever testing node 22 on ubuntu 24.04
- ubuntu 26.04 needs libnet-idn-encode-perl, since Net::IDN::Encode no longer compiles with gcc 15. It is a build and a runtime dependency
- Fixed a race in thirdparty that let a parallel make run bin/cpanm while it was still being downloaded
- Fixed the version rewrite rule, which replaced every dotted number triple in README.md and had repeatedly corrupted the example listen address and the cpanfile snapshot name

## 0.3.1 - 2023-03-24

- Sort numeric columns numerically
- Send emails only if everything before successes
- 'Send by Email' is now the default option
- Also show 'Last Handshake' column

## 0.3.0 - 2023-03-22

- Fixed incorrect handling of #+comment tags
- Extended IPManager module, we now support address reservations and per interface defaults

## 0.2.3 - 2022-12-25

- Raised wg-meta version to 0.3.3 to fix deadlock when calling the reload callback

## 0.2.2 - 2022-11-25

- fixed ip suggestions

## 0.2.1 - 2022-07-25

- updated: Build dependency node.js to 18 LTS (ubuntu 20+22) 16LTS (ubuntu 18)
- updated: Callbackery to 0.42.4
- updated: Added Ubuntu 22 as build target

## 0.2.0 - 2021-07-18

- fixed: Validation on hidden field when adding a new peer
- fixed: Disabled Peer warning when editing a peer
- changed: lifted wg-meta compatibility to 0.3.x. This version may be incompatible to older (wg-meta) metadata! See changes of wg-meta

## 0.1.4 - 2021-04-07

- wg-wrangler: removed .pl extension from main "binary" (to make it compatible for apparmor profiles)

## 0.1.3 - 2021-04-07

- package: store config in /etc/opt/wg-wrangler, made systemd-service configurable
- wg-wrangler: migrated value attributes to getAllFieldValues()

## 0.1.2 - 2021-04-06

- package: added config options for the --listen argument
- development: Allow development without having wireguard installed

## 0.1.1 - 2021-04-30

- Initial deb release

## 0.1.0 - 2021-04-16

- Initial release
