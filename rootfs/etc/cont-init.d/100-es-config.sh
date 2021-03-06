#!/usr/bin/with-contenv bash
# shellcheck shell=bash
. "/usr/local/bin/logger"
program_name="es-config"

# Install es config if not existing
if [ ! -f "/config/zmeventnotification.ini" ]; then
  echo "Copying Neo ZMES Configuration" | init "[${program_name}] "
  # .ini and .yml files
  s6-setuidgid www-data \
    cp -r /zoneminder/defaultconfiges/* /config
fi

# tools
if [ ! -d "/config/estools" ]; then
  echo "Copying Neo ZMES Tools" | info "[${program_name}] "
  s6-setuidgid www-data cp -r /zoneminder/estools /config
fi

if [ ! -d "/config/known_faces" ] || [ ! -d "/config/unknown_faces" ]; then
  echo "Creating (un)known faces directories" | init "[${program_name}] "
  s6-setuidgid www-data \
    mkdir /config/known_faces \
    /config/unknown_faces
fi

if [ ! -f "/config/objectconfig.yml" ]; then
  echo "Copying Object Detection (Hooks) Configuration with Secrets" | init "[${program_name}] "
  s6-setuidgid www-data \
    cp /zoneminder/defaultconfiges/objectconfig.yml /config
  s6-setuidgid www-data \
    cp /zoneminder/defaultconfiges/zm_secrets.yml /config
fi

echo "Setting ES ZoneMinder URL settings..." | info "[${program_name}] "
sed -i "/^\[secrets\]$/,/^\[/ s|^ZM_PORTAL.*=.*|ZM_PORTAL=https://${ES_COMMON_NAME}|" /config/secrets.ini

enable_auth="no"
if [ "${ES_ENABLE_AUTH}" -eq 1 ]; then
  enable_auth="yes"
fi
echo "Setting ES ZoneMinder Auth ($enable_auth) settings..." | info "[${program_name}] "
sed -i "/^\[auth\]$/,/^\[/ s|^enable.*=.*|enable=${enable_auth}|" /config/zmeventnotification.ini


echo "Configuring ZoneMinder Common Name (${ES_COMMON_NAME}) in Nginx Config" | info "[${program_name}] "
sed -i "s|ES_COMMON_NAME|${ES_COMMON_NAME}|g" /etc/nginx/conf.d/ssl.conf