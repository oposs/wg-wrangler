# The build and test environment of wg-wrangler (D18 container driver).
#
# `make` on the host builds this image, `make check` runs the test suite in it
# and `make dist` builds the source tarball in it. The release packages are
# built separately, one container per distribution (release-build-local.yml).
#
# Debian 13 carries node 20 in its own archive, the oldest node configure
# accepts, so the frontend builds without a third-party node repository.
FROM docker.io/library/debian:13

ENV DEBIAN_FRONTEND=noninteractive

# autoconf, automake and make run the build below. The XS modules under
# thirdparty/ need the compiler and the -dev packages; gcc 14 and later no
# longer compile Net::IDN::Encode from CPAN, hence the distribution package.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      autoconf automake make gcc g++ libc6-dev pkg-config \
      perl gettext curl ca-certificates openssl tar \
      libqrencode-dev libssl-dev zlib1g-dev libnet-idn-encode-perl \
      nodejs npm \
 && rm -rf /var/lib/apt/lists/*

COPY . /src
WORKDIR /src

RUN ./bootstrap \
 && ./configure --disable-container \
 && make \
 && make install
