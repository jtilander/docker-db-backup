# Easily automated database dumps

This container [jtilander/backup-db](https://hub.docker.com/r/jtilander/backup-db/) provides an immediate way and a scheduled way to take ascii database dumps from both mysql and postgres. These dumps have the convinient property that they are easily restorable with this container as well.

## Why?

The case for having the ascii SQL dumps instead of just the native file system files might be non obvious at first. The file system files are fine, but they do have race conditions and are susecptible to corruption. 

The file system files are also platform dependent and possibly version dependent. 

The dumps on the other hand can be transfered between architectures as well as sometimes between versions (usually upwards). 

Having periodical dumps of the database can also provide snapshots that you can travel back to in need.




## Assumptions

This container assumes that we have access to the global docker daemon, and we will execute commands in the target database container. It will also assume that we've got proper database credentials setup. 

A good way to setup this container would be to have an instance running for each target database that you want to backup periodically.

# Usage

## Modes

We can run in three modes:

* backup: this will backup the target database from "db" once
* restore: this will restore the most recent database file into the host "db"
* cron: this will continiually run a backup operation ever night

The mode is chosen by the command to the docker container. 

## Volumes

|Mount point|Suggested|Description|
|-----------|---------|-----------|
|/var/run/docker.sock|/var/run/docker.sock|Needed for docker access|
|/data|/mnt/backup/databases|All the backup archives will be written / read from here|


## Environment variables

Most of the functionality is controlled by the container's environment variables.

|Name         |Default      |Description|
|-------------|-------------|-----------|
|DEBUG        |0            |Set to 1 for debug output|
|HISTORY      |5            |How many snapshots to keep in a rolling fashion|
|DBNAME       |database_name|The target database name (mostly for mysql) to backup|
|USERNAME     |root         |Database credentials|
|PASSWORD     |password     |Database credentials|
|DBTYPE       |mysql        |Valid choices are mysql, psql|
|PREFIX       |backup       |The archive files are prefixed this way|
|CONTAINER    |$DBTYPE      |The name of the container running the database|
|CRONSCHEDULE |0 * * * *    |Crontab entry for when to run the periodic backup|


## Sample

The [docker-compose](https://github.com/jtilander/docker-db-backup/blob/master/docker-compose.yml) file gives an example of launching two databases and then triggering periodic backups on these (one each minute) into a temporary directory. It should give a good idea of what is possible.


