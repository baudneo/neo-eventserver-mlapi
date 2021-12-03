#!/usr/bin/with-contenv bash
# shellcheck shell=bash
. "/usr/local/bin/logger"
program_name="es-config"

# Install es config if not existing
if [ ! -f "/config/zmeventnotification.ini" ]; then
  echo "Copying ES Configuration" | init "[${program_name}] "
  s6-setuidgid www-data \
    cp -r /zoneminder/defaultconfiges/* /config

fi
if [ ! -f "/config/objectconfig.yml" ]; then
  echo "Copying Object Detection (Hooks) Configuration with Secrets" | init "[${program_name}] "
  s6-setuidgid www-data \
    cp -r /zoneminder/defaultconfiges/hooks/objectconfig.yml /config
fi

echo "Setting ES ZoneMinder URL settings..." | info "[${program_name}] "
sed -i "/^\[secrets\]$/,/^\[/ s|^ZMES_PICTURE_URL.*=.*|ZMES_PICTURE_URL=${ZMES_PICTURE_URL}" /config/secrets.ini
sed -i "/^\[secrets\]$/,/^\[/ s|^ZM_PORTAL.*=.*|ZM_PORTAL=https://${ES_COMMON_NAME}|" /config/secrets.ini

echo "Setting ES ZoneMinder Auth settings..." | info "[${program_name}] "
enable_auth="no"
if [ "${ES_ENABLE_AUTH}" -eq 1 ]; then
  enable_auth="yes"
fi
sed -i "/^\[auth\]$/,/^\[/ s|^enable.*=.*|enable=${enable_auth}|" /config/zmeventnotification.ini

echo "Configuring Object Detection (Hooks) for MLAPI communication..." | info "[${program_name}] "
sed -i "s/base_data_path: .*$/base_data_path: \'/config\'/g" /config/objectconfig.yml


echo "Configuring ZoneMinder Common Name in Nginx Config" | info "[${program_name}] "
sed -i "s|ES_COMMON_NAME|${ES_COMMON_NAME}|g" /etc/nginx/conf.d/ssl.conf
