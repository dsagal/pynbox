# Based on https://github.com/rlincoln/nacl_sdk

FROM ubuntu:16.04
ENV DEBIAN_FRONTEND noninteractive
ENV SDK_VERSION 50
ENV NACL_ARCH x86_64
ENV NACL_SDK_ROOT /nacl_sdk/pepper_$SDK_VERSION
ENV PATH /depot_tools:/webports/src/bin:$PATH

# 'Multilib' libraries are required to compile 32-bit versions, e.g. relied on by the python-host port.
RUN apt-get update && apt-get install -y \
        bzip2 \
        curl \
        g++-multilib \
        gcc-multilib \
        git \
        lib32stdc++6 \
        libc6-i386 \
        python \
        python-dev \
        python-pip \
        unzip \
        wget \
        zip

# Configure git
RUN git config --global user.email "pynbox-webports@example.com"
RUN git config --global user.name "Pynbox Webports"

# Google's depot_tools
RUN git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git

# NaCl SDK
RUN curl -O -L https://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/nacl_sdk.zip
RUN unzip nacl_sdk.zip && rm nacl_sdk.zip
RUN ./nacl_sdk/naclsdk install pepper_$SDK_VERSION

# 32-bit OpenSSL (needed for python-host, which is needed by Python).
WORKDIR /openssl
RUN curl https://www.openssl.org/source/openssl-1.0.2j.tar.gz | tar -zxv
WORKDIR /openssl/openssl-1.0.2j
RUN setarch i386 ./config -m32 ; make ; make install
ENV SSL32_CFLAGS '-I/usr/local/ssl/include'
ENV SSL32_LDFLAGS '-L/usr/local/ssl/lib'

# NaCl Webports.
WORKDIR /webports
RUN gclient config --name=src https://github.com/dsagal/webports.git && gclient sync --revision src@75dba3c

# Build the webports.
WORKDIR /webports/src

# NACL_BARE=1 is a variable added to our webports clone, used e.g. in the
# Python build to omit certain Chrome-specific libraries.
ENV NACL_BARE 1

RUN make V=2 F=0 FROM_SOURCE=1 TOOLCHAIN=glibc CFLAGS=$SSL32_CFLAGS LDFLAGS=$SSL32_LDFLAGS python-host

# Includes the builds of python and python3. These are time-consuming, so it's nice to have them
# prebuilt as part of the image.
RUN bin/webports -v -V -t glibc build python
RUN bin/webports -v -V -t glibc build python3

VOLUME /host/packages
VOLUME /host/build
