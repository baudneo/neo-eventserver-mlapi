#!/usr/bin/with-contenv bash
# shellcheck shell=bash
. "/usr/local/bin/logger"
program_name="es-mariadb-config"
# ==============================================================================
# es-config
# Configure default es Settings
# ==============================================================================
insert_command=""

if [ "$(mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" zm \
    -e "SELECT Value FROM Config WHERE Name = 'ZM_AUTH_HASH_SECRET';" \
    | cut -f 2 \
    | sed -n '2 p')" == "...Change me to something unique..." ]; then

  echo "Configuring ZoneMinder API Defaults..." | init "[$program_name] "
  insert_command+="UPDATE Config SET Value = 'builtin' WHERE Name = 'ZM_AUTH_TYPE';"
  insert_command+="UPDATE Config SET Value = 'hashed' WHERE Name = 'ZM_AUTH_RELAY';"
  insert_command+="UPDATE Config SET Value = 0 WHERE Name = 'ZM_AUTH_HASH_IPS';"

  if [ "${USE_SECURE_RANDOM_ORG}" -eq 1 ]; then
    echo "Fetching random secure string for ZoneMinder API from random.org..." | init "[$program_name] "
    random_string=$(
      wget -qO - \
        "https://www.random.org/strings/?num=4&len=20&digits=on&upperalpha=on&loweralpha=on&unique=on&format=plain&rnd=new" \
      | tr -d '\n' \
    )
  else
    echo "Generating standard random string for ZoneMinder API..." | init "[$program_name] "
    random_string="$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM$RANDOM"
  fi

  insert_command+="UPDATE Config SET Value = '${random_string}' WHERE Name = 'ZM_AUTH_HASH_SECRET';"

fi

if [ "$ES_DEBUG_ENABLED" -eq 1 ]; then
    echo "ES_DEBUG_ENABLED flag is enabled, setting DEBUG via the DB" | info "[$program_name] "
    insert_command+="UPDATE Config SET Value = 1 WHERE Name = 'ZM_LOG_DEBUG';"
    # This is 0 or 1, does not support 'levels'
    insert_command+="UPDATE Config SET Value = 1 WHERE Name = 'ZM_LOG_DEBUG_LEVEL';"
    insert_command+="UPDATE Config SET Value = '_zmeventnotification' WHERE Name = 'ZM_LOG_DEBUG_TARGET';"
    elif [ "$ES_DEBUG_ENABLED" -eq 0 ]; then
    insert_command+="UPDATE Config SET Value = 0 WHERE Name = 'ZM_LOG_DEBUG';"
    insert_command+="UPDATE Config SET Value = 0 WHERE Name = 'ZM_LOG_DEBUG_LEVEL';"
    insert_command+="UPDATE Config SET Value = '' WHERE Name = 'ZM_LOG_DEBUG_TARGET';"
fi
# Always keep syslog enabled
insert_command+="UPDATE Config SET Value = 5 WHERE Name = 'ZM_LOG_LEVEL_SYSLOG';"
# Always keep file logging off ?
insert_command+="UPDATE Config SET Value = 0 WHERE Name = 'ZM_LOG_DEBUG_FILE';"
insert_command+="UPDATE Config SET Value = -5 WHERE Name = 'ZM_LOG_LEVEL_FILE';"

echo "Forcibly enabling API and disabling ES daemon..." | info "[$program_name] "
insert_command+="UPDATE Config SET Value = 1 WHERE Name = 'ZM_OPT_USE_API';"
insert_command+="UPDATE Config SET Value = 0 WHERE Name = 'ZM_OPT_USE_EVENTNOTIFICATION';"

echo "Applying DB changes..." | info "[$program_name] "
mysql -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" -h"${MYSQL_HOST}" zm -e "${insert_command}"
