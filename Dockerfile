# syntax=docker/dockerfile:experimental
ARG ZM_VERSION=main
ARG ES_VERSION=master
ARG MLAPIDB_USER=mlapi_user
ARG MLAPIDB_PASS=ZoneMinder
ARG MLAPI_CONTAINER=mlapi
ARG MLAPI_PORT=5000

#####################################################################
#                                                                   #
# Download Neo ES                                                   #
#                                                                   #
#####################################################################
FROM alpine:latest AS eventserverdownloader
ARG ES_VERSION
WORKDIR /eventserverdownloader

RUN set -x \
    && apk add git \
    && git clone https://github.com/baudneo/zmeventnotification.git . \
    && git checkout ${ES_VERSION}
#####################################################################
#                                                                   #
# Download Neo PYZM                                                 #
#                                                                   #
#####################################################################
FROM alpine:latest AS pyzmdl
WORKDIR /pyzmdownloader

RUN set -x \
    && apk add git \
    && git clone https://github.com/baudneo/pyzm . \
    && git checkout master
#####################################################################
#                                                                   #
# Convert rootfs to LF using dos2unix                               #
# Alleviates issues when git uses CRLF on Windows                   #
#                                                                   #
#####################################################################
FROM alpine:latest as rootfs-converter
WORKDIR /rootfs

RUN set -x \
    && apk add --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community/ \
        dos2unix

COPY rootfs .
RUN set -x \
    && find . -type f -print0 | xargs -0 -n 1 -P 4 dos2unix

#####################################################################
#                                                                   #
# Install ES                                                        #
# Apply changes to default ES config                                #
#                                                                   #
#####################################################################
#FROM ghcr.io/zoneminder-containers/zoneminder-base:${ZM_VERSION}
FROM baudneo/containers-testing:ZM
ARG ES_VERSION
ARG MLAPI_CONTAINER
ARG MLAPI_PORT
ARG MLAPIDB_USER
ARG MLAPIDB_PASS

RUN set -x \
    && apt-get update \
    && apt-get install -y \
        build-essential \
        libjson-perl \
        libyaml-perl \
        libgeos-dev \
        python3-pip \
    && PERL_MM_USE_DEFAULT=1 \
    && yes | perl -MCPAN -e "install Net::WebSocket::Server" \
    && yes | perl -MCPAN -e "install LWP::Protocol::https" \
    && yes | perl -MCPAN -e "install Config::IniFiles" \
    && yes | perl -MCPAN -e "install Time::Piece" \
    && yes | perl -MCPAN -e "install Net::MQTT::Simple" \
    && yes | perl -MCPAN -e "install YAML::Tiny" \
    && yes | perl -MCPAN -e "install YAML::XS"


# Need 'hook' to send detection to mlapi
#RUN #--mount=type=bind,target=/tmp/eventserver,source=/eventserverdownloader,from=eventserverdownloader,rw \
COPY --from=eventserverdownloader /eventserverdownloader /tmp/eventserver
RUN set -x \
    && cd /tmp/eventserver \
    && mkdir -p /zoneminder/defaultconfiges \
    && TARGET_CONFIG=/zoneminder/defaultconfiges \
        MAKE_CONFIG_BACKUP='' \
        WEB_OWNER=www-data \
        WEB_GROUP=www-data \
        ./install.sh \
            --install-es \
            --install-hook \
            --no-install-pyzm \
            --install-config \
            --no-interactive \
            --no-pysudo \
    && mkdir -p /zoneminder/estools \
    && cp ./tools/* /zoneminder/estools \
    && cp /zoneminder/estools/es.debug.objdet /usr/bin/es.d \
    && cp /zoneminder/estools/es.baredebug.objdet /usr/bin/es.bd \
    && rm -rf /tmp/eventserver

# Intel VAAPI
RUN apt-get install -y gnupg \
    && wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | apt-key add - \
    && echo 'deb [arch=amd64] https://repositories.intel.com/graphics/ubuntu focal main' > /etc/apt/sources.list.d/intel-graphics.list \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys F63F0F2B90935439 \
    && echo 'deb http://ppa.launchpad.net/kisak/kisak-mesa/ubuntu focal main' > /etc/apt/sources.list.d/kisak-mesa-focal.list \
    && rm -rf /var/lib/apt/lists/*

RUN apt-get -qq update \
    && apt-get -qq install --no-install-recommends -y \
    libva-drm2 libva2 libmfx1 i965-va-driver vainfo intel-media-va-driver-non-free mesa-vdpau-drivers mesa-va-drivers mesa-vdpau-drivers libdrm-radeon1 \
    && rm -rf /var/lib/apt/lists/*

# nvidia layer (see https://gitlab.com/nvidia/container-images/cuda/blob/master/dist/11.1/ubuntu20.04-x86_64/base/Dockerfile)
RUN apt-get update && apt-get install -y --no-install-recommends \
      curl \
    && wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/cuda-ubuntu1804.pin \
    && sudo mv ./cuda-ubuntu1804.pin /etc/apt/preferences.d/cuda-repository-pin-600 \
    && curl -fSsL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64/7fa2af80.pub | apt-key add - \
    && echo "deb https://developer.download.nvidia.com/compute/cuda/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/cuda.list \
    && echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1804/x86_64 /" > /etc/apt/sources.list.d/nvidia-ml.list \
    && rm -rf /var/lib/apt/lists/*
# CUDA
ENV CUDA_VERSION 10.2
# For libraries in the cuda-compat-* package: https://docs.nvidia.com/cuda/eula/index.html#attachment-a
RUN apt-get update && apt-get install -y --no-install-recommends \
        cuda-cudart-10-2=10.2.89-1 \
        cuda-compat-10-2=440.95.01-1 \
    && ln -s cuda-10.2 /usr/local/cuda \
    && rm -rf /var/lib/apt/lists/*

# Required for nvidia-docker v1
RUN echo "/usr/local/nvidia/lib" >> /etc/ld.so.conf.d/nvidia.conf && \
    echo "/usr/local/nvidia/lib64" >> /etc/ld.so.conf.d/nvidia.conf

# Fix default es config for mlapi
# https://stackoverflow.com/a/16987794
# This sets where the tokens.txt file will be created as well
RUN set -x \
    && sed -i "/^\[general\]$/,/^\[/ s|^secrets.*=.*|secrets=/config/secrets.ini|" /zoneminder/defaultconfiges/zmeventnotification.ini \
    && sed -i "/^\[fcm\]$/,/^\[/ s|^token_file.*=.*|token_file=/config/tokens.txt|" /zoneminder/defaultconfiges/zmeventnotification.ini \
    && sed -i "/^\[customize\]$/,/^\[/ s|^console_logs.*=.*|console_logs=yes|" /zoneminder/defaultconfiges/zmeventnotification.ini \
    && sed -i "/^\[customize\]$/,/^\[/ s|^use_hooks.*=.*|use_hooks=yes|" /zoneminder/defaultconfiges/zmeventnotification.ini \
    && sed -i "/^\[network\]$/,/^\[/ s|^.*address.*=.*|address=0.0.0.0|" /zoneminder/defaultconfiges/zmeventnotification.ini \
    && sed -i "/^\[auth\]$/,/^\[/ s|^enable.*=.*|enable=no|" /zoneminder/defaultconfiges/zmeventnotification.ini \
    && sed -i "s|ml_enable:.*|ml_enable: yes|" /zoneminder/defaultconfiges/objectconfig.yml \
    && sed -i "s|gateway:.*|gateway: http://${MLAPI_CONTAINER}:${MLAPI_PORT}/api/v1|" /zoneminder/defaultconfiges/objectconfig.yml \
    && sed -i "s|secrets:.*|secrets: /config/zm_secrets.yml|" /zoneminder/defaultconfiges/objectconfig.yml \
    && sed -i "s|base_data_path:.*|base_data_path: /var/lib/zmeventnotification|" /zoneminder/defaultconfiges/objectconfig.yml \
    && sed -i "s|coral_models:.*|coral_models: /config/models/coral_edgetpu|" /zoneminder/defaultconfiges/objectconfig.yml \
    && sed -i "s|yolo4_models:.*|yolo4_models: /config/models/yolov4|" /zoneminder/defaultconfiges/objectconfig.yml \
    && sed -i "s|yolo3_models:.*|yolo3_models: /config/models/yolov3|" /zoneminder/defaultconfiges/objectconfig.yml \
    && sed -i "s|tinyyolo_models:.*|tinyyolo_models: /config/models/tinyyolov|" /zoneminder/defaultconfiges/objectconfig.yml \
    && sed -i "s|known_images_path:.*|known_images_path: /config/known_faces|" /zoneminder/defaultconfiges/objectconfig.yml \
    && sed -i "s|unknown_images_path:.*|unknown_images_path: /config/unknown_faces|" /zoneminder/defaultconfiges/objectconfig.yml
# Fix default es secrets
RUN set -x \
    && sed -i "/^\[secrets\]$/,/^\[/ s|^ES_CERT_FILE.*=.*|ES_CERT_FILE=/config/ssl/cert.cer|" /zoneminder/defaultconfiges/secrets.ini \
    && sed -i "/^\[secrets\]$/,/^\[/ s|^ES_KEY_FILE.*=.*|ES_KEY_FILE=/config/ssl/key.pem|" /zoneminder/defaultconfiges/secrets.ini
COPY --from=pyzmdl /pyzmdownloader /tmp/pyzm
RUN set -x \
    && cd /tmp/pyzm \
    && python3 -m pip install imageio \
    && python3 -m pip install opencv-contrib-python \
    && python3 setup.py install \
    && rm -rf /tmp/pyzm \
    && rm -rf /root/.cache/pip

# Copy rootfs
COPY --from=rootfs-converter /rootfs /

ENV \
    ES_DEBUG_ENABLED=1\
    ES_COMMON_NAME=localhost\
    ES_ENABLE_AUTH=0\
    ES_ENABLE_DHPARAM=1\
    USE_SECURE_RANDOM_ORG=1\
    MLAPIDB_USER=mlapi_user\
    MLAPIDB_PASS=ZoneMinder\
    MLAPI_CONTAINER=mlapi\
    MLAPI_PORT=5000


LABEL com.github.baudneo.es_version=${ES_VERSION}

EXPOSE 443/tcp
EXPOSE 9000/tcp
