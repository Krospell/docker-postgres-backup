#!/bin/bash
# Script to restore a Docker containerized PostgreSQL database from a dump file
# Usage: restore.sh my-backup.dump

###########################
####### LOAD CONFIG #######
###########################

while [ $# -gt 0 ]; do
        case $1 in
                -c)
                        CONFIG_FILE_PATH="$2"
                        shift 2
                        ;;
                *)
                        ${ECHO} "Unknown Option \"$1\"" 1>&2
                        exit 2
                        ;;
        esac
done

if [ -z $CONFIG_FILE_PATH ] ; then
        SCRIPTPATH=$(cd ${0%/*} && pwd -P)
        CONFIG_FILE_PATH="${SCRIPTPATH}/docker_pg_restore.config"
fi

if [ ! -r ${CONFIG_FILE_PATH} ] ; then
        echo "Could not load config file from ${CONFIG_FILE_PATH}. Exiting." 1>&2
        exit 1
fi

source "${CONFIG_FILE_PATH}"

###########################
#### PRE-BACKUP CHECKS ####
###########################

# Verify that this script is running as the specified user
if [ "$BACKUP_USER" != "" -a "$(id -un)" != "$BACKUP_USER" ] ; then
	echo "This script must be run as $BACKUP_USER. Exiting." 1>&2
	exit 1
fi

if [ ! $PG_PASS ]; then
    echo "Make sure the user password for $USERNAME is provided in the configuration file. Exiting." 1>&2
    exit 1
fi

###########################
### INITIALISE DEFAULTS ###
###########################

if [ ! $HOSTNAME ]; then
	HOSTNAME="localhost"
fi;

if [ ! $USERNAME ]; then
	USERNAME="postgres"
fi;


###########################
#### Restore dump ####
###########################
	echo "Restoring the backup to $DATABASE"
	
	###########################
	###### FULL RESTORE #######
	###########################
    echo -e "\n\nPerforming full database restore"
    echo -e "--------------------------------------------\n"

    if [ $ENABLE_PLAIN_BACKUPS = "yes" ]
        then
            echo "Restoring backup $1"

            set -o pipefail
            if ! docker exec "$CONTAINER_NAME" /bin/bash -c "PGPASSWORD=${PG_PASS} pg_restore --verbose --clean --no-acl --no-owner --username ${USERNAME} --dbname ${DATABASE} ${1}"; then
                    echo "[!!ERROR!!] Failed to restore plain backup" 1>&2
            else
            # Move the backup file from localhost to the remote destination
                    echo "[SUCCESS] Backup has been restored to database ${DATABASE}"
            fi
            set +o pipefail

    fi

    echo -e "\nAll database restoration complete!"
