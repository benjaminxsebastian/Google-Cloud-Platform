#!/bin/bash


INSTALL_FILE_PATH="./sendgrid-email-delivery-install.txt"
LOG_FILE_PATH="./setup-sendgrid-email-delivery-log.txt"
EXIM4_CONFIGURATION_FILE_PATH="/etc/exim4/update-exim4.conf.conf"
EXIM4_BACKUP_CONFIGURATION_FILE_PATH="/etc/exim4/update-exim4.conf.bak"
EXIM4_TEMPORARY_CONFIGURATION_FILE_PATH="/etc/exim4/update-exim4.conf.tmp"
EXIM4_MACROS_FILE_PATH="/etc/exim4/exim4.conf.localmacros"
EXIM4_BACKUP_MACROS_FILE_PATH="/etc/exim4/exim4.conf.localmacros.bak"
EXIM4_TEMPORARY_MACROS_FILE_PATH="/etc/exim4/exim4.conf.localmacros.tmp"
EXIM4_CLIENT_PASSWORD_FILE_PATH="/etc/exim4/passwd.client"
EXIM4_BACKUP_CLIENT_PASSWORD_FILE_PATH="/etc/exim4/passwd.client.bak"
EXIM4_TEMPORARY_CLIENT_PASSWORD_FILE_PATH="/etc/exim4/passwd.client.tmp"


log() {
    rawTimestamp=$(date +%2H:%2M:%2S.%3N_%2d/%2m/%4Y)
    timestamp=${rawTimestamp/_/ (}")"
    echo "$timestamp : [$1] $2"
}

# Save stdout and stderr to file descriptors 3 and 4, then redirect them to $LOG_FILE_PATH.
exec 3>&1 4>&2 >$LOG_FILE_PATH 2>&1
if [ ! -f $INSTALL_FILE_PATH ]; then
    INSTANCE_NAME=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/name" -H "Metadata-Flavor: Google")
    INSTANCE_ZONE=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/zone" -H "Metadata-Flavor: Google")
    log "INFO " "Starting SendGrid Email Delivery installation."
    echo ""
    log "INFO " "Setting the system timezone to America/New_York: "
    timedatectl set-timezone America/New_York
    log "INFO " "System timezone: "
    timedatectl
    log "INFO " "Done setting the system timezone."
    echo ""
    log "INFO " "Installing the mailutils packages on the system: "
    apt -y install mailutils
    log "INFO " "Done installing packages on the system."
    echo ""
    log "INFO " "Configuring Exim Internet Mailer: "
    if [ -f $EXIM4_CONFIGURATION_FILE_PATH ]; then
        cp -f $EXIM4_CONFIGURATION_FILE_PATH $EXIM4_BACKUP_CONFIGURATION_FILE_PATH
        grep -v "dc_eximconfig_configtype=" $EXIM4_CONFIGURATION_FILE_PATH > $EXIM4_TEMPORARY_CONFIGURATION_FILE_PATH && mv $EXIM4_TEMPORARY_CONFIGURATION_FILE_PATH $EXIM4_CONFIGURATION_FILE_PATH
        grep -v "dc_smarthost=" $EXIM4_CONFIGURATION_FILE_PATH > $EXIM4_TEMPORARY_CONFIGURATION_FILE_PATH && mv $EXIM4_TEMPORARY_CONFIGURATION_FILE_PATH $EXIM4_CONFIGURATION_FILE_PATH
        grep -v "dc_hide_mailname=" $EXIM4_CONFIGURATION_FILE_PATH > $EXIM4_TEMPORARY_CONFIGURATION_FILE_PATH && mv $EXIM4_TEMPORARY_CONFIGURATION_FILE_PATH $EXIM4_CONFIGURATION_FILE_PATH
    fi
    echo "dc_eximconfig_configtype='smarthost'" >> $EXIM4_CONFIGURATION_FILE_PATH
    echo "dc_smarthost='smtp.sendgrid.net::587'" >> $EXIM4_CONFIGURATION_FILE_PATH
    echo "dc_hide_mailname='true'" >> $EXIM4_CONFIGURATION_FILE_PATH
    if [ -f $EXIM4_MACROS_FILE_PATH ]; then
        cp -f $EXIM4_MACROS_FILE_PATH $EXIM4_BACKUP_MACROS_FILE_PATH
        grep -v "MAIN_TLS_ENABLE=" $EXIM4_MACROS_FILE_PATH > $EXIM4_TEMPORARY_MACROS_FILE_PATH && mv $EXIM4_TEMPORARY_MACROS_FILE_PATH $EXIM4_MACROS_FILE_PATH
    fi
    echo "MAIN_TLS_ENABLE=1" >> $EXIM4_MACROS_FILE_PATH
    log "INFO " "Getting SendGrid Email Delivery API Key from Metadata Server: "
    SENDGRID_EMAIL_DELIVERY_API_KEY=$(curl "http://metadata.google.internal/computeMetadata/v1/instance/attributes/SENDGRID_EMAIL_DELIVERY_API_KEY" -H "Metadata-Flavor: Google")
    log "INFO " "Obtained SendGrid Email Delivery API Key from Metadata Server."
    if [ -f $EXIM4_CLIENT_PASSWORD_FILE_PATH ]; then
        cp -f $EXIM4_CLIENT_PASSWORD_FILE_PATH $EXIM4_BACKUP_CLIENT_PASSWORD_FILE_PATH
        grep -v "$SENDGRID_EMAIL_DELIVERY_API_KEY" $EXIM4_CLIENT_PASSWORD_FILE_PATH > $EXIM4_TEMPORARY_CLIENT_PASSWORD_FILE_PATH && mv $EXIM4_TEMPORARY_CLIENT_PASSWORD_FILE_PATH $EXIM4_CLIENT_PASSWORD_FILE_PATH
    fi
    echo "*:apikey:$SENDGRID_EMAIL_DELIVERY_API_KEY" >> $EXIM4_CLIENT_PASSWORD_FILE_PATH
    gcloud compute instances remove-metadata $INSTANCE_NAME --keys=SENDGRID_EMAIL_DELIVERY_API_KEY --zone=$INSTANCE_ZONE
    log "INFO " "Done configuring Exim Internet Mailer."
    echo ""
    log "INFO " "Restarting SendGrid Email Delivery: "
    /etc/init.d/exim4 restart
    log "INFO " "Restarted SendGrid Email Delivery."
    log "INFO " "Creating SendGrid Email Delivery install file: "
    mv $LOG_FILE_PATH $INSTALL_FILE_PATH
    log "INFO " "Created SendGrid Email Delivery install file."
    echo ""
    log "INFO " "Completed SendGrid Email Delivery installation."
fi
gcloud compute instances remove-metadata $INSTANCE_NAME --keys=startup-script --zone=$INSTANCE_ZONE
exec 1>&3 2>&4
