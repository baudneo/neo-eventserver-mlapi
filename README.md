# eventserver-mlapi

[//]: # ([![Docker Build]&#40;https://github.com/baudneo/eventserver-base/actions/workflows/docker-build.yaml/badge.svg&#41;]&#40;https://github.com/zoneminder-containers/eventserver-base/actions/workflows/docker-build.yaml&#41;)
![Status](https://img.shields.io/badge/Status-ALPHA-red)

# Why

The source eventserver-base does not include hooks for running ML. This is an attempt to interface with the new 
mlapi_cudnn-base image.

# Variables

New environment variables available in addition to zoneminder-base
1. ES_DEBUG_ENABLED
    - Enables --debug flag for event notification when set to 1
2. ES_COMMON_NAME
    - Defines common name for accessing zoneminder
3. ES_ENABLE_AUTH
    - Controls ES/ZM Authentication
4. ZMES_PICTURE_URL
    - The url that zmNinja will use to grab push notification JPG/GIF/MP4.
5. USE_SECURE_RANDOM_ORG
    - Use random.org for api random string generation. Otherwise uses bash random.
6. MLAPI_CONTAINER
    - The name of the mlapi container in docker-compose, this sets the mlapi_gateway to send http detection requests.
7. MLAPIDB_USER
    - user for mlapi (mlapi DB)
8. MLAPIDB_PASS
    - password for mlapi user (mlapi DB)


# Certificates
If a certificate is located at `/config/ssl/cert.cer` with a corresponding
private key at `/config/ssl/key.pem`, a self-signed certificate will not be
generated. Otherwise, one will be automatically generated using the common name
environment variable.
