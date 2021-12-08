# eventserver-mlapi

[![Docker Build](https://github.com/baudneo/eventserver-mlapi/actions/workflows/docker-build.yaml/badge.svg)](https://github.com/baudneo/eventserver-mlapi/actions/workflows/docker-build.yaml)

![Status](https://img.shields.io/badge/Status-BETA-yellow)

# Why

The source [eventserver-base](https://github.com/zoneminder-containers/eventserver-base) does not include hooks for running ML. This is an attempt to interface with the new 
mlapi_cudnn-base image (Tested working on bare metal host, Unprivileged LXC as docker host support is a work in progress).

# Variables

New environment variables available in addition to [zoneminder-base](https://github.com/baudneo/zoneminder-base)
1. ES_DEBUG_ENABLED
    - Enables --debug flag for event notification when set to 1
2. ES_COMMON_NAME
    - Defines common name for accessing zoneminder (creates self-signed ssl certs if none supplied)
3. ES_ENABLE_AUTH
    - Controls ES/ZM Authentication
4. ZMES_PICTURE_URL
    - The url that zmNinja will use to grab push notification JPG/GIF/MP4.
5. USE_SECURE_RANDOM_ORG
    - Use random.org for api random string generation. Otherwise, uses bash random.
6. MLAPI_CONTAINER
    - The name of the mlapi container in docker-compose or MLAPI' IP address.
7. MLAPI_PORT
    - The port that the mlapi container is listening on.
8. MLAPIDB_USER
    - user for mlapi (mlapi DB)
9. MLAPIDB_PASS
    - password for mlapi user (mlapi DB)
10. UNPRIV_LXC
     - If set to 1, will attempt to change some runtime settings to allow ZoneMinder/Neo ZMES to run with MLAPI container. (WIP, not working)
11. PYZM_CONFPATH
    - Path to the zm.conf config file DIRECTORY /config (or /etc/zm) not /config/zm.conf
# Certificates
If a certificate is located at `/config/ssl/cert.cer` with a corresponding
private key at `/config/ssl/key.pem`, a self-signed certificate will not be
generated. Otherwise, one will be automatically generated using the common name
(ES_COMMON_NAME) environment variable.
