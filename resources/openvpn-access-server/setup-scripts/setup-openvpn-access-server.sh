#!/bin/bash


INSTALL_FILE_PATH="./openvpn-access-server-install.txt"
LOG_FILE_PATH="./setup-openvpn-access-server-log.txt"
CRON_JOB_FILE_PATH="./openvpn-access-server-install-cronjob.txt"


log() {
    rawTimestamp=$(date +%2H:%2M:%2S.%3N_%2d/%2m/%4Y)
    timestamp=${rawTimestamp/_/ (}")"
    echo "$timestamp : [$1] $2"
}

# Save stdout and stderr to file descriptors 3 and 4, then redirect them to $LOG_FILE_PATH.
exec 3>&1 4>&2 >$LOG_FILE_PATH 2>&1
log "INFO " "Getting OpenVPN Access Server instance name and user name from Metadata Server: "
INSTANCE_NAME=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
INSTANCE_ZONE=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google")
OPENVPN_ACCESS_SERVER_USER_NAME=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/OPENVPN_ACCESS_SERVER_USER_NAME" -H "Metadata-Flavor: Google")
log "INFO " "Obtained OpenVPN Access Server instance name and user name from Metadata Server."
echo "Starting OpenVPN Access Server installation at: $(date)" | mail -s "Starting OpenVPN Access Server Installation" --append="FROM:$OPENVPN_ACCESS_SERVER_USER_NAME@gmail.com" $OPENVPN_ACCESS_SERVER_USER_NAME@gmail.com
if [ ! -f $INSTALL_FILE_PATH ]; then
    log "INFO " "Starting OpenVPN Access Server installation."
    echo ""
    log "INFO " "Setting the system timezone to America/New_York: "
    timedatectl set-timezone America/New_York
    log "INFO " "System timezone: "
    timedatectl
    log "INFO " "Done setting the system timezone."
    echo ""
    log "INFO " "Installing the ca-certificates wget net-tools gnupg packages on the system: "
    apt -y install ca-certificates wget net-tools gnupg
    log "INFO " "Done installing packages on the system."
    echo ""
    log "INFO " "Fetch and add repository key to the system: "
    wget -qO - https://as-repository.openvpn.net/as-repo-public.gpg | apt-key add -
    log "INFO " "Done adding repository key to the system."
    echo ""
    log "INFO " "Add repository to the system: "
    echo "deb http://as-repository.openvpn.net/as/debian bullseye main">/etc/apt/sources.list.d/openvpn-as-repo.list
    log "INFO " "Done adding repository to the system."
    echo ""
    log "INFO " "Updating the system: "
    apt update
    log "INFO " "Done updating the system."
    log "INFO " "Installing OpenVPN Access Server on the system: "
    apt -y install openvpn-as
    log "INFO " "Done installing OpenVPN Access Server on the system."
    echo ""
    log "INFO " "Getting OpenVPN Access Server password from Metadata Server: "
    OPENVPN_ACCESS_SERVER_USER_PASSWORD=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/OPENVPN_ACCESS_SERVER_USER_PASSWORD" -H "Metadata-Flavor: Google")
    log "INFO " "Obtained OpenVPN Access Server password from Metadata Server."
    echo ""
    log "INFO " "Creating new user: "$OPENVPN_ACCESS_SERVER_USER_NAME": "
    useradd $OPENVPN_ACCESS_SERVER_USER_NAME
    log "INFO " "Created new user: "$OPENVPN_ACCESS_SERVER_USER_NAME"."
    echo ""
    log "INFO " "Setting password for user: "$OPENVPN_ACCESS_SERVER_USER_NAME": "
    chpasswd <<< $OPENVPN_ACCESS_SERVER_USER_NAME":"$OPENVPN_ACCESS_SERVER_USER_PASSWORD
    /usr/local/openvpn_as/scripts/sacli --user $OPENVPN_ACCESS_SERVER_USER_NAME --new_pass $OPENVPN_ACCESS_SERVER_USER_PASSWORD SetLocalPassword
    gcloud compute instances remove-metadata $INSTANCE_NAME --keys=OPENVPN_ACCESS_SERVER_USER_PASSWORD --zone=$INSTANCE_ZONE
    log "INFO " "Done setting password for user: "$OPENVPN_ACCESS_SERVER_USER_NAME"."
    echo ""
    log "INFO " "Making user: "$OPENVPN_ACCESS_SERVER_USER_NAME" an administrator: "
    /usr/local/openvpn_as/scripts/sacli --user $OPENVPN_ACCESS_SERVER_USER_NAME --key "prop_superuser" --value "true" UserPropPut
    log "INFO " "Made user: "$OPENVPN_ACCESS_SERVER_USER_NAME" an administrator."
    echo ""
    log "INFO " "Configuring OpenVPN Access Server log files: "
    echo "LOG_ROTATE_LENGTH=1000000" >> /usr/local/openvpn_as/etc/as.conf
    log "INFO " "Configured OpenVPN Access Server log files."
    echo ""
    log "INFO " "Scheduling cron job to remove old log files: "
    crontab -l > $CRON_JOB_FILE_PATH
    echo "0 4 * * * rm /var/log/openvpnas.log.{15..1000} >/dev/null 2>&1" >> $CRON_JOB_FILE_PATH
    crontab $CRON_JOB_FILE_PATH
    log "INFO " "Scheduled cron job to remove old log files."
    echo ""
    log "INFO " "Reupdate the system: "
    apt update
    log "INFO " "Done reupdating the system."
    echo ""
    log "INFO " "Upgrading the system: "
    apt -y upgrade
    log "INFO " "Done upgrading the system."
    echo ""
    log "INFO " "Creating OpenVPN Access Server install file: "
    mv $LOG_FILE_PATH $INSTALL_FILE_PATH
    log "INFO " "Created OpenVPN Access Server install file."
    echo ""
    log "INFO " "Completed OpenVPN Access Server installation."
    echo ""
fi
log "INFO " "Getting OpenVPN Access Server external IP address: "
OPENVPN_ACCESS_SERVER_IP_ADDRESS=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip" -H "Metadata-Flavor: Google")
log "INFO " "Obtained OpenVPN Access Server external IP address."
echo ""
log "INFO " "Setting OpenVPN Access Server IP Address to: "$OPENVPN_ACCESS_SERVER_IP_ADDRESS": "
/usr/local/openvpn_as/scripts/sacli --key "host.name" --value $OPENVPN_ACCESS_SERVER_IP_ADDRESS ConfigPut
log "INFO " "Set OpenVPN Access Server IP Address."
echo ""
log "INFO " "Restarting OpenVPN Access Server: "
/usr/local/openvpn_as/scripts/sacli stop
/usr/local/openvpn_as/scripts/sacli start
service openvpnas restart
log "INFO " "Restarted OpenVPN Access Server."
echo "Completed OpenVPN Access Server installation at: $(date)" | mail -A "$INSTALL_FILE_PATH" -s "Completed OpenVPN Access Server Installation" --append="FROM:$OPENVPN_ACCESS_SERVER_USER_NAME@gmail.com" $OPENVPN_ACCESS_SERVER_USER_NAME@gmail.com
gcloud compute instances remove-metadata $INSTANCE_NAME --keys=OPENVPN_ACCESS_SERVER_USER_NAME --zone=$INSTANCE_ZONE
gcloud compute instances remove-metadata $INSTANCE_NAME --keys=startup-script --zone=$INSTANCE_ZONE
exec 1>&3 2>&4
