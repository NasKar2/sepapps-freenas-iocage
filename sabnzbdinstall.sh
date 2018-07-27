#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 with  Sabnzbd
# https://github.com/NasKar2/sepapps-freenas-iocage

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

# Initialize defaults
JAIL_IP=""
DEFAULT_GW_IP=""
INTERFACE=""
VNET="off"
POOL_PATH=""
APPS_PATH=""
SABNZBD_DATA=""
MEDIA_LOCATION=""
TORRENTS_LOCATION=""


SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/sabnzbd-config
CONFIGS_PATH=$SCRIPTPATH/configs

# Check for sabnzbd-config and set configuration
if ! [ -e $SCRIPTPATH/sabnzbd-config ]; then
  echo "$SCRIPTPATH/sabnzbd-config must exist."
  exit 1
fi

# Check that necessary variables were set by sabnzbd-config
if [ -z $JAIL_IP ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z $DEFAULT_GW_IP ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z $INTERFACE ]; then
  echo 'Configuration error: INTERFACE must be set'
  exit 1
fi
if [ -z $POOL_PATH ]; then
  echo 'Configuration error: POOL_PATH must be set'
  exit 1
fi

if [ -z $APPS_PATH ]; then
  echo 'Configuration error: APPS_PATH must be set'
  exit 1
fi

if [ -z $JAIL_NAME ]; then
  echo 'Configuration error: JAIL_NAME must be set'
  exit 1
fi

if [ -z $SABNZBD_DATA ]; then
  echo 'Configuration error: SABNZBD_DATA must be set'
  exit 1
fi

if [ -z $MEDIA_LOCATION ]; then
  echo 'Configuration error: MEDIA_LOCATION must be set'
  exit 1
fi

if [ -z $TORRENTS_LOCATION ]; then
  echo 'Configuration error: TORRENTS_LOCATION must be set'
  exit 1
fi

#
# Create Jail
echo '{"pkgs":["nano","mono","mediainfo","sqlite3","ca_root_nss","curl"]}' > /tmp/pkg.json
iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r 11.1-RELEASE ip4_addr="${INTERFACE}|${JAIL_IP}/24" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}"

rm /tmp/pkg.json

#
# needed for installing from ports
#mkdir -p ${PORTS_PATH}/ports
#mkdir -p ${PORTS_PATH}/db

#mkdir -p ${POOL_PATH}/${APPS_PATH}/${SONARR_DATA}
#mkdir -p ${POOL_PATH}/${APPS_PATH}/${RADARR_DATA}
#mkdir -p ${POOL_PATH}/${APPS_PATH}/${LIDARR_DATA}
mkdir -p ${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}
#mkdir -p ${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
mkdir -p ${POOL_PATH}/${MEDIA_LOCATION}
mkdir -p ${POOL_PATH}/${TORRENTS_LOCATION}
echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}'"
#echo "mkdir -p '${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}'"

#sonarr_config=${POOL_PATH}/${APPS_PATH}/${SONARR_DATA}
#radarr_config=${POOL_PATH}/${APPS_PATH}/${RADARR_DATA}
#lidarr_config=${POOL_PATH}/${APPS_PATH}/${LIDARR_DATA}
sabnzbd_config=${POOL_PATH}/${APPS_PATH}/${SABNZBD_DATA}
#plex_config=${POOL_PATH}/${APPS_PATH}/${PLEX_DATA}
#iocage exec ${JAIL_NAME} mkdir -p /mnt/configs
iocage exec ${JAIL_NAME} 'sysrc ifconfig_epair0_name="epair0b"'

#
# mount ports so they can be accessed in the jail
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/ports /usr/ports nullfs rw 0 0
#iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/db /var/db/portsnap nullfs rw 0 0

iocage fstab -a ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${sabnzbd_config} /config nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${MEDIA_LOCATION} /mnt/media nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/${TORRENTS_LOCATION} /mnt/torrents nullfs rw 0 0

iocage restart ${JAIL_NAME}
  
# add media group to media user
#iocage exec ${JAIL_NAME} pw groupadd -n media -g 8675309
#iocage exec ${JAIL_NAME} pw groupmod media -m media
#iocage restart ${JAIL_NAME} 

#
# Make media owner of data directories
#chown -R media:media $sonarr_config/
#chown -R media:media $radarr_config/
#chown -R media:media $lidarr_config/
#chown -R media:media $sabnzbd_config/
#chown -R plex:plex $plex_config/
#chown -R media:media ${POOL_PATH}/${MEDIA_LOCATION}
#chown -R media:media ${POOL_PATH}/${TORRENTS_LOCATION}

#
# Make pkg upgrade get the latest repo
iocage exec ${JAIL_NAME} mkdir -p /usr/local/etc/pkg/repos/
iocage exec ${JAIL_NAME} cp -f /mnt/configs/FreeBSD.conf /usr/local/etc/pkg/repos/FreeBSD.conf

#
# Upgrade to the lastest repo
iocage exec ${JAIL_NAME} pkg upgrade -y
iocage restart ${JAIL_NAME}

#
# Install Sabnzbd
iocage exec ${JAIL_NAME} pkg install -y sabnzbdplus
iocage exec ${JAIL_NAME} ln -s /usr/local/bin/python2.7 /usr/bin/python
iocage exec ${JAIL_NAME} ln -s /usr/local/bin/python2.7 /usr/bin/python2
iocage exec ${JAIL_NAME} "pw groupmod media -m _sabnzbd"
iocage exec ${JAIL_NAME} chown -R media:media /mnt/torrents/sabnzbd /config
iocage exec ${JAIL_NAME} sysrc "sabnzbd_user=media"
iocage exec ${JAIL_NAME} sysrc sabnzbd_enable=YES
iocage exec ${JAIL_NAME} sysrc sabnzbd_conf_dir="/config/${SABNZBD_DATA}"
iocage exec ${JAIL_NAME} cp -f /mnt/configs/sabnzbd /usr/local/etc/rc.d/sabnzbd
#echo "sabnzbd_data ${SABNZBD_DATA}"
iocage exec ${JAIL_NAME} sed -i '' "s/sabnzbddata/${SABNZBD_DATA}/" /usr/local/etc/rc.d/sabnzbd
iocage exec ${JAIL_NAME} sed -i '' "s/sabnzbdpid/${SABNZBD_DATA}/" /usr/local/etc/rc.d/sabnzbd
iocage exec ${JAIL_NAME} chmod u+x /usr/local/etc/rc.d/sabnzbd
#iocage exec ${JAIL_NAME} chown -R media:media /usr/local/etc/rc.d/sabnzbd


iocage restart ${JAIL_NAME}
iocage exec ${JAIL_NAME} service sabnzbd start
iocage exec ${JAIL_NAME} service sabnzbd stop
iocage exec ${JAIL_NAME} sed -i '' -e 's?host = 127.0.0.1?host = 0.0.0.0?g' /config/${SABNZBD_DATA}/sabnzbd.ini
iocage exec ${JAIL_NAME} sed -i '' -e 's?download_dir = Downloads/incomplete?download_dir = /mnt/torrents/sabnzbd/incomplete?g' /config/${SABNZBD_DATA}/sabnzbd.ini
iocage exec ${JAIL_NAME} sed -i '' -e 's?complete_dir = Downloads/complete?complete_dir = /mnt/torrents/sabnzbd/complete?g' /config/${SABNZBD_DATA}/sabnzbd.ini
iocage exec ${JAIL_NAME} service sabnzbd start

echo "Sabnzbd installed"


#
# remove /mnt/configs as no longer needed
#iocage fstab -r ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0

echo

echo "sabnzbd should be available at http://${JAIL_IP}:8080"
