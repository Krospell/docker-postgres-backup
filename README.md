This repository contains scripts allowing for Docker contained PSQL instances to be backed up and restored on-demand.

# Usage
**NOTA**: This script must be run on the host with the database installed.

## Configuration
See the `.env` file to configure the required values for backups and restorations.
## Automation
You can automate the usage of this script by using a _cronjob_
```bash
0 0 * * * bash /home/sysadmin/docker-postgres-backup/backup.sh
```
## Restoration
To restore a database, use
```bash
# Make sure that you are in the dir where the script is stored
restore.sh my-database.dump
```

>Maintainer: loan.joliveau@numigi.com