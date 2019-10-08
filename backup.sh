#!/bin/bash

export configdir=/config
export sourcedir=/tobackup

BACKUP_MYSQL=0
BACKUP_MONGODB=0

if [ -e $configdir/backup.conf ]; then
    source $configdir/backup.conf
fi

mysqlbackup() {
    BACKUP_DIR="$backupdir/local/$weekday/mysql"
    MYSQL_USER="backup"
    MYSQL=/usr/bin/mysql
    MYSQL_PASSWORD="BAt8RqVQbFezqJqn"
    MYSQLDUMP=/usr/bin/mysqldump
 
    mkdir -p "$BACKUP_DIR"
 
    databases=`$MYSQL --user=$MYSQL_USER -p$MYSQL_PASSWORD -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`
 
    for db in $databases; do
        $MYSQLDUMP --force --opt --user=$MYSQL_USER -p$MYSQL_PASSWORD --databases $db | gzip > "$BACKUP_DIR/$db.gz"
    done

#        mysqldump -u backup -p'BAt8RqVQbFezqJqn' -Acx > $backupdir/local/$weekday/mysql.dump
#        tar -cjpf $backupdir/local/$weekday/mysql.dump.tar.bz2 $backupdir/local/$weekday/mysql.dump
#        rm -r $backupdir/local/$weekday/mysql.dump
}

mongodbbackup() {
    false
#    mongodump --out $backupdir/local/$weekday/mongodb.dump
#    tar -cjpf $backupdir/local/$weekday/mongodb.dump.tar.bz2 $backupdir/local/$weekday/mongodb.dump
#    rm -r $backupdir/local/$weekday/mongodb.dump
}

rsyncbackup() {
    for d in $sourcedir/*; do
        name=`basename $d`
        opts="-avxWH --safe-links --delete"
        if [ -f "$configdir/$name.options" ] ; then
            opts="$opts `cat \"$configdir/$name.options\" | tr '\n' ' '`"
        fi
        if [ -f "$configdir/$name.exclude" ] ; then
            opts="$opts --exclude-from=$configdir/$name.exclude --delete-excluded"
        fi
        echo "Synchronisiere $name..."
        nice -n 18 rsync $opts "$d/" "$RSYNC_TARGET/$name/"
    done
}

date

if [ "$BACKUP_MYSQL" == "1" ]; then
    mysqlbackup
fi

if [ "$BACKUP_MONGODB" == "1" ]; then
    mongodbbackup
fi

if [ "$RSYNC_TARGET" != "" ]; then
    localbackup
fi
