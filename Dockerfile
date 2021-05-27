############################################################
# Dockerfile - Janus Gateway on Debian Buster
# https://github.com/kmeyerhofer/docker-janus
# (Forked from: https://github.com/krull/docker-janus)
############################################################

# set base image debian jessie
FROM debian:buster

# file maintainer author
LABEL maintainer="kmeyerhofer <k@kcmr.io>"

# library versions
ARG   JANUS_VERSION=0.10.7
ARG LIBSRTP_VERSION=2.2.0
ARG LIBNICE_VERSION=0.1.17

# docker build arguments
ARG JANUS_WITH_POSTPROCESSING="1"
ARG JANUS_WITH_BORINGSSL="0"
ARG JANUS_WITH_DOCS="0"
ARG JANUS_WITH_REST="1"
ARG JANUS_WITH_DATACHANNELS="1"
ARG JANUS_WITH_WEBSOCKETS="1"
ARG JANUS_WITH_MQTT="0"
ARG JANUS_WITH_PFUNIX="1"
ARG JANUS_WITH_RABBITMQ="0"
# https://groups.google.com/d/msg/meetecho-janus/QX-VEoIdlLE/YVS99Am5BAAJ
ARG JANUS_WITH_FREESWITCH_PATCH="0"
ARG JANUS_CONFIG_DEPS="\
    --prefix=/opt/janus \
    "
ARG JANUS_CONFIG_OPTIONS=""
ARG JANUS_BUILD_DEPS_DEV="\
    libcurl4-openssl-dev \
    libjansson-dev \
    libssl-dev \
    libsofia-sip-ua-dev \
    libglib2.0-dev \
    libopus-dev \
    libogg-dev \
    liblua5.3-dev \
    pkg-config \
    libconfig-dev \
    gtk-doc-tools \
    meson \
    ninja-build \
    "
#    libnice-dev \ # Version 0.1.14 - outdated
ARG JANUS_BUILD_DEPS_EXT="\
    libavutil-dev \
    libavcodec-dev \
    libavformat-dev \
    libunwind-dev \
    gengetopt \
    libtool \
    automake \
    git-core \
    build-essential \
    cmake \
    ca-certificates \
    curl \
    "

# init build env
RUN set -x && \
    export JANUS_WITH_POSTPROCESSING="${JANUS_WITH_POSTPROCESSING}" && \
    export JANUS_WITH_BORINGSSL="${JANUS_WITH_BORINGSSL}" && \
    export JANUS_WITH_DOCS="${JANUS_WITH_DOCS}" && \
    export JANUS_WITH_REST="${JANUS_WITH_REST}" && \
    export JANUS_WITH_DATACHANNELS="${JANUS_WITH_DATACHANNELS}" && \
    export JANUS_WITH_WEBSOCKETS="${JANUS_WITH_WEBSOCKETS}" && \
    export JANUS_WITH_MQTT="${JANUS_WITH_MQTT}" && \
    export JANUS_WITH_PFUNIX="${JANUS_WITH_PFUNIX}" && \
    export JANUS_WITH_RABBITMQ="${JANUS_WITH_RABBITMQ}" && \
    export JANUS_WITH_FREESWITCH_PATCH="${JANUS_WITH_FREESWITCH_PATCH}" && \
    export JANUS_BUILD_DEPS_DEV="${JANUS_BUILD_DEPS_DEV}" && \
    export JANUS_CONFIG_OPTIONS="${JANUS_CONFIG_OPTIONS}" && \
    if [ $JANUS_WITH_POSTPROCESSING = "1" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --enable-post-processing"; fi && \
    if [ $JANUS_WITH_BORINGSSL = "1" ]; then export JANUS_BUILD_DEPS_DEV="$JANUS_BUILD_DEPS_DEV golang-go" && export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --enable-boringssl --enable-dtls-settimeout"; fi && \
    if [ $JANUS_WITH_DOCS = "1" ]; then export JANUS_BUILD_DEPS_DEV="$JANUS_BUILD_DEPS_DEV graphviz" && export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --enable-docs"; fi && \
    if [ $JANUS_WITH_REST = "1" ]; then export JANUS_BUILD_DEPS_DEV="$JANUS_BUILD_DEPS_DEV libmicrohttpd-dev"; else export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-rest"; fi && \
    if [ $JANUS_WITH_DATACHANNELS = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-data-channels"; fi && \
    if [ $JANUS_WITH_WEBSOCKETS = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-websockets"; fi && \
    if [ $JANUS_WITH_MQTT = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-mqtt"; fi && \
    if [ $JANUS_WITH_PFUNIX = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-unix-sockets"; fi && \
    if [ $JANUS_WITH_RABBITMQ = "0" ]; then export JANUS_CONFIG_OPTIONS="$JANUS_CONFIG_OPTIONS --disable-rabbitmq"; fi

# install apt deps
RUN set -x && \
    /usr/sbin/groupadd -r janus && /usr/sbin/useradd -r -g janus janus && \
    DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install $JANUS_BUILD_DEPS_DEV ${JANUS_BUILD_DEPS_EXT}

WORKDIR /usr/local/src

# build libsrtp
RUN set -x && \
    curl -fSL https://github.com/cisco/libsrtp/archive/v${LIBSRTP_VERSION}.tar.gz -o ./v${LIBSRTP_VERSION}.tar.gz && \
    tar xzf ./v${LIBSRTP_VERSION}.tar.gz -C . && \
    cd ./libsrtp-${LIBSRTP_VERSION} && \
    ./configure --prefix=/usr --enable-openssl && \
    make shared_library && \
    make install

# build libnice
RUN set -x && \
    curl -fSL https://github.com/libnice/libnice/archive/${LIBNICE_VERSION}.tar.gz -o ./${LIBNICE_VERSION}.tar.gz && \
    tar xzf ./${LIBNICE_VERSION}.tar.gz -C . && \
    cd ./libnice-${LIBNICE_VERSION} && \
    if [ ${LIBNICE_VERSION} > "0.1.17" ]; then meson builddir && \
      sudo ninja -C builddir install && \
    elif [ ${LIBNICE_VERSION} < "0.1.18" ]; then ./autogen.sh && \
      ./configure --prefix=/usr && \
      make && \
      make install \
    ; fi

# build boringssl
RUN set -x && \
    if [ $JANUS_WITH_BORINGSSL = "1" ]; then git clone https://boringssl.googlesource.com/boringssl ./boringssl && \
      cd ./boringssl && \
      sed -i s/" -Werror"//g CMakeLists.txt && \
      mkdir -p ./build && \
      cd ./build && \
      cmake -DCMAKE_CXX_FLAGS="-lrt" .. && \
      make && \
      cd ../ && \
      mkdir -p /opt/boringssl && \
      cp -R ./boringssl/include /opt/boringssl/ && \
      mkdir -p /opt/boringssl/lib && \
      cp ./boringssl/build/ssl/libssl.a /opt/boringssl/lib/ && \
      cp ./boringssl/build/crypto/libcrypto.a /opt/boringssl/lib/ \
    ; fi

# build usrsctp
RUN set -x && \
    if [ $JANUS_WITH_DATACHANNELS = "1" ]; then git clone https://github.com/sctplab/usrsctp ./usrsctp && \
      cd ./usrsctp && \
      ./bootstrap && \
      ./configure --prefix=/usr && \
      make && \
      make install \
    ; fi

# build libwebsockets
RUN set -x && \
    if [ $JANUS_WITH_WEBSOCKETS = "1" ]; then git clone https://github.com/warmcat/libwebsockets.git ./libwebsockets && \
      # cd ./libwebsockets && \
      # git checkout v1.5-chrome47-firefox41 && \
      mkdir ./libwebsockets/build && \
      cd ./libwebsockets/build && \
      cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr -DCMAKE_C_FLAGS="-fpic" .. && \
      make && \
      make install \
    ; fi

# build paho.mqtt.c
RUN set -x && \
    if [ $JANUS_WITH_MQTT = "1" ]; then git clone https://github.com/eclipse/paho.mqtt.c.git ./paho.mqtt.c && \
      cd ./paho.mqtt.c && \
      make && \
      make install \
    ; fi

# build rabbitmq-c
RUN set -x && \
    if [ $JANUS_WITH_RABBITMQ = "1" ]; then git clone https://github.com/alanxz/rabbitmq-c ./rabbitmq-c && \
      cd ./rabbitmq-c && \
      git submodule init && \
      git submodule update && \
      autoreconf -i && \
      ./configure --prefix=/usr && \
      make && \
      make install \
    ; fi

# build doxygen
RUN set -x && \
    if [ $JANUS_WITH_DOCS = "1" ]; then curl -fSL https://github.com/doxygen/doxygen/archive/Release_1_8_19.tar.gz -o ./v1.8.19.tar.gz && \
      tar xzf ./v1.8.19.tar.gz -C . && \
      cd ./doxygen-Release_1_8_19 && \
      mkdir build && \
      cmake -G "Unix Makefiles" .. && \
      make && \
      make install \
    ; fi

# build janus-gateway
RUN set -x && \
    git clone --depth 1 --branch v${JANUS_VERSION} https://github.com/meetecho/janus-gateway.git ./janus-gateway && \
    if [ $JANUS_WITH_FREESWITCH_PATCH = "1" ]; then curl -fSL https://raw.githubusercontent.com/krull/docker-misc/master/init_fs/tmp/janus_sip.c.patch -o ./janus-gateway/plugins/janus_sip.c.patch && \
      cd ./janus-gateway/plugins && patch < janus_sip.c.patch \
    ; fi && \
    cd ./janus-gateway && \
    ./autogen.sh && \
    ./configure ${JANUS_CONFIG_DEPS} $JANUS_CONFIG_OPTIONS && \
    make && \
    make install

# folder ownership
RUN set -x && \
    chown -R janus:janus /opt/janus

# build cleanup
RUN set -x && \
    if [ $JANUS_WITH_BORINGSSL = "1" ]; then rm -rf boringssl; fi && \
    if [ $JANUS_WITH_DATACHANNELS = "1" ]; then rm -rf usrsctp; fi && \
    if [ $JANUS_WITH_WEBSOCKETS = "1" ]; then rm -rf libwebsockets; fi && \
    if [ $JANUS_WITH_MQTT = "1" ]; then rm -rf paho.mqtt.c; fi && \
    if [ $JANUS_WITH_RABBITMQ = "1" ]; then rm -rf rabbitmq-c; fi && \
    rm -rf \
      ${LIBNICE_VERSION}.tar.gz \
      v${LIBSRTP_VERSION}.tar.gz \
      libnice-${LIBNICE_VERSION} \
      libsrtp-${LIBSRTP_VERSION} \
      janus-gateway && \
    DEBIAN_FRONTEND=noninteractive apt-get -y --auto-remove purge ${JANUS_BUILD_DEPS_EXT} && \
    DEBIAN_FRONTEND=noninteractive apt-get -y clean && \
    DEBIAN_FRONTEND=noninteractive apt-get -y autoclean && \
    DEBIAN_FRONTEND=noninteractive apt-get -y autoremove && \
    rm -rf /usr/share/locale/* && \
    rm -rf /var/cache/debconf/*-old && \
    rm -rf /usr/share/doc/* && \
    rm -rf /var/lib/apt/*

USER janus

CMD ["/opt/janus/bin/janus"]
