#!/bin/bash
# Script to backup a Docker containerized PostgreSQL database to a remote machine
# This script allows for retention parameters and creates global backups
# Backups are made locally and then pushed to a remote using the `scp` protocol

# Log this script output to a file
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1> "$BACKUP_DIR"/log/backup.log 2>&1

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
        CONFIG_FILE_PATH="${SCRIPTPATH}/.env"
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
#### START THE BACKUPS ####
###########################

function perform_backups()
{
	SUFFIX=$1
	FINAL_BACKUP_DIR=$BACKUP_DIR"`date +\%Y-\%m-\%d`$SUFFIX/"

	echo "Making the backup directory in $FINAL_BACKUP_DIR"

	if ! mkdir -p $FINAL_BACKUP_DIR; then
		echo "Cannot create backup directory in $FINAL_BACKUP_DIR. Go and fix it!" 1>&2
		exit 1;
	fi;
	
	###########################
	###### FULL BACKUPS #######
	###########################
    echo -e "\n\nPerforming full database backups"
    echo -e "--------------------------------------------\n"

    if [ $ENABLE_PLAIN_BACKUPS = "yes" ]
        then
            echo "Plain global backup of all databases"

            set -o pipefail
            if ! docker exec "$CONTAINER_NAME" /bin/bash -c "PGPASSWORD=${PG_PASS} pg_dump --format=custom --dbname ${DATABASE} --username ${USERNAME}" | gzip > $FINAL_BACKUP_DIR"global".dump.gz.in_progress; then
                    echo "[!!ERROR!!] Failed to produce plain backup" 1>&2
            else
            # Move the backup file from localhost to the remote destination
                    mv $FINAL_BACKUP_DIR"global".dump.gz.in_progress $FINAL_BACKUP_DIR"global".dump.gz && scp -r $FINAL_BACKUP_DIR "${REMOTE_NAME}":"${BACKUP_DIR}"
            fi
            set +o pipefail

    fi

    echo -e "\nAll database backups complete!"
}

# MONTHLY BACKUPS

DAY_OF_MONTH=`date +%d`

if [ $DAY_OF_MONTH -eq 1 ];
then
	# Delete all expired monthly directories
	find $BACKUP_DIR -maxdepth 1 -name "*-monthly" -exec rm -rf '{}' ';'
	        	
	perform_backups "-monthly"
	
	exit 0;
fi

# WEEKLY BACKUPS

DAY_OF_WEEK=`date +%u` #1-7 (Monday-Sunday)
EXPIRED_DAYS=`expr $((($WEEKS_TO_KEEP * 7) + 1))`

if [ $DAY_OF_WEEK = $DAY_OF_WEEK_TO_KEEP ];
then
	# Delete all expired weekly directories
	find $BACKUP_DIR -maxdepth 1 -mtime +$EXPIRED_DAYS -name "*-weekly" -exec rm -rf '{}' ';'
	        	
	perform_backups "-weekly"
	
	exit 0;
fi

# DAILY BACKUPS

# Delete daily backups 7 days old or more
find $BACKUP_DIR -maxdepth 1 -mtime +$DAYS_TO_KEEP -name "*-daily" -exec rm -rf '{}' ';'

perform_backups "-daily"