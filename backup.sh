#!/bin/bash

export configdir=/config
export backupdir=/tobackup

BACKUP_MYSQL=0
BACKUP_MONGODB=0

if [ -e $configdir/backup.conf ]; then
    source $configdir/backup.conf
fi

mysqlbackup() {
    if [ "$MYSQL_HOST" == "" -o "$MYSQL_USER" == "" -o "$MYSQL_PASSWORD" == "" ]; then
        echo "MYSQL_HOST, MYSQL_USER and MYSQL_PASSWORD has to be set."
        exit 2
    fi

    mycnf="$configdir/my.cnf"
    echo "[mysql]" > "$mycnf"
    echo "user=$MYSQL_USER" >> "$mycnf"
    echo "password=$MYSQL_PASSWORD" >> "$mycnf"
    echo "[mysqldump]" >> "$mycnf"
    echo "user=$MYSQL_USER" >> "$mycnf"
    echo "password=$MYSQL_PASSWORD" >> "$mycnf"

    MYSQL=/usr/bin/mysql
    MYSQLDUMP=/usr/bin/mysqldump
 
    dir="$backupdir/mysql/$MYSQL_HOST"
    mkdir -p "$dir"
 
    rm -rf "$dir/*"

    databases=`$MYSQL "--defaults-file=$mycnf" -h "$MYSQL_HOST" -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)"`
 
    for db in $databases; do
        echo "Creating dump of MySQL database $db..."
        $MYSQLDUMP "--defaults-file=$mycnf" --force --opt -h "$MYSQL_HOST" --skip-lock-tables --databases $db | gzip > "$dir/$db.gz"
    done
}

mongodbbackup() {
    if [ "$MONGODB_HOST" == "" ]; then
        echo "MYSQL_HOST, MYSQL_USER and MYSQL_PASSWORD has to be set."
        exit 2
    fi
    
    dir="$backupdir/mongodb/$MONGODB_HOST"
    mkdir -p "$dir"

    rm -rf "$dir/*"

    echo "Creating MongoDB dump..."
    if [ "$MONGODB_USER" == "" -o "$MONGODB_PASSWORD" == "" ]; then
        mongodump -o "$dir" -h "$MONGODB_HOST" --gzip --forceTableScan
    else
        mongodump -o "$dir" -h "$MONGODB_HOST" -u "$MONGODB_USER" -p "$MONGODB_PASSWORD" --gzip --forceTableScan
    fi
}

rsyncbackup() {
    for d in $backupdir/*; do
        name=`basename $d`
        opts="-avxWH --munge-links --delete"
        if [ -f "$configdir/$name.options" ] ; then
            opts="$opts `cat \"$configdir/$name.options\" | tr '\n' ' '`"
        fi
        if [ -f "$configdir/$name.exclude" ] ; then
            opts="$opts --exclude-from=$configdir/$name.exclude --delete-excluded"
        fi
        echo "Synchronisiere $name..."
        nice -n 18 rsync $opts "${RSYNC_OPTS[@]}" "$d/" "$RSYNC_TARGET/$name/"
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
    rsyncbackup
fi
