ARG IMAGE_VERSION_TAG

FROM ubuntu:$IMAGE_VERSION_TAG

LABEL maintainer="oetiker" \
      description="WG-wrangler builder"


ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -y update && \
    apt-get -y install apt-utils curl && \
    curl https://deb.nodesource.com/setup_12.x | bash && \
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
        g++
        
COPY make-deb.sh /make-deb.sh

RUN chmod 777 /make-deb.sh

ENTRYPOINT ["/make-deb.sh"]
