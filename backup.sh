#!/bin/bash

export configdir=/config
export backupdir=/backup
export sourcedir=/tobackup

DATECMD="date +%u"
BACKUP_MYSQL=0
BACKUP_MONGODB=0
ENCFS_MODE="off"
REMOTE_PORT=22
RSYNCD_CONFIG="/config/rsyncd.config"
SSH_IDENTITY="/config/id_rsa"

if [ -e $configdir/backup.conf ]; then
    source $configdir/backup.conf
fi

mkdir -p "$backupdir/local"
mkdir -p "$backupdir/rsync"

_mount() {
    encfs_file=".encfs6.xml"
    if [ "$ENCFS_MODE" == "off" ]; then
        mount --bind "$backupdir/local" "$backupdir/rsync"
    elif [ "$ENCFS_MODE" == "on" ]; then
        if [ -f "$backupdir/rsync/$encfs_file" ]; then
            echo "Mounting encfs..."
            echo "$ENCFS_PASSWORD" | encfs -S "$backupdir/rsync" "$backupdir/local"
        elif [ "$ENCFS_PASSWORD" != "" ]; then
            mv "$backupdir/local" "$backupdir/temp"
            mkdir "$backupdir/local"
            echo "Creating and mounting encfs..."
            echo -e "$ENCFS_PASSWORD\n$ENCFS_PASSWORD" | encfs -S "$backupdir/rsync" "$backupdir/local"
            echo "Migrating old backups..."
            rsync -av "$backupdir/temp/" "$backupdir/local/"
            rm -rf "$backupdir/temp"
        else
            echo "Can not create encfs, no password set."
            exit 2
        fi
    elif [ "$ENCFS_MODE" == "reverse" ]; then
        mkdir -p "$backupdir/rsync/encfs"
        if [ -f "$backupdir/local/$encfs_file" ]; then
            echo "Reverse mounting encfs..."
            echo "$ENCFS_PASSWORD" | encfs -S --reverse "$backupdir/local" "$backupdir/rsync/encfs"
        elif [ -f "$backupdir/rsync/$encfs_file" ]; then
            echo "An encfs was found in $backupdir/rsync/."
            exit 3
        elif [ "$ENCFS_PASSWORD" != "" ]; then
            echo "Creating and reverse mounting encfs..."
            echo -e "$ENCFS_PASSWORD\n$ENCFS_PASSWORD" | encfs -S --reverse "$backupdir/local" "$backupdir/rsync/encfs"
            cp "$backupdir/local/$encfs_file" "$backupdir/rsync/$encfs_file"
        else
            echo "Can not create encfs, no password set."
            exit 2
        fi
    else
        echo "Unknown encfs-mode: $ENCFS_MODE"
        exit 1
    fi
}

_umount() {
    if [ "$ENCFS_MODE" == "off" ]; then
        umount "$backupdir/rsync"
    elif [ "$ENCFS_MODE" == "on" ]; then
        umount "$backupdir/local"
    elif [ "$ENCFS_MODE" == "reverse" ]; then
        umount "$backupdir/rsync/encfs"
    fi
}

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
#    mongodump --out $backupdir/local/$weekday/mongodb.dump
#    tar -cjpf $backupdir/local/$weekday/mongodb.dump.tar.bz2 $backupdir/local/$weekday/mongodb.dump
#    rm -r $backupdir/local/$weekday/mongodb.dump
}

localbackup() {

    bname=`$DATECMD`
    tmp=`ls -l $backupdir/local/current | awk '{print $11}'`
    tmp=`basename $tmp`
    if [ "$tmp" != "$bname" ]; then
        mkdir -p $backupdir/local/$bname
        rm -rf $backupdir/local/$bname/*
        cp -rpl $backupdir/local/current/* $backupdir/local/$bname/ > /dev/null 2> /dev/null
    fi

    date

    if [ "$BACKUP_MYSQL" == "1" ]; then
        mysqlbackup
    fi

    if [ "$BACKUP_MONGODB" == "1" ]; then
        mongodbbackup
    fi

    for d in $sourcedir/*; do
        name=`basename $d`
        opts="-avxWH --safe-links --delete"
        if [ -f "$configdir/$name.options" ] ; then
            opts="$opts `cat \"$configdir/$name.options\" | tr '\n' ' '`"
        fi
        if [ -f "$configdir/$name.exclude" ] ; then
            opts="$opts --exclude-from=$configdir/$name.exclude --delete-excluded"
        fi
        mkdir -p "$backupdir/local/$bname/$name"
        echo "Synchronisiere lokal $name..."
        nice -n 18 rsync $opts "$d/" "$backupdir/local/$bname/$name/"
    done

    rm -f $backupdir/local/last
    mv $backupdir/local/current $backupdir/local/last
    ln -s $backupdir/local/$bname $backupdir/local/current
    echo
    for i in $backupdir/local/current/* ; do
        i=`basename $i`
        oldsize=0`du -sb $backupdir/local/last/$i | cut -f1`
        newsize=0`du -sb $backupdir/local/current/$i | cut -f1`
        /usr/local/bin/printsizediff.py $i $oldsize $newsize
    done
    echo "======================================================"
    oldsize=0`du -sb $backupdir/local/last/ | cut -f1`
    newsize=0`du -sb $backupdir/local/current/ | cut -f1`
    /usr/local/bin/printsizediff.py "" $oldsize $newsize
}

sshbackup() {
    date
    
    if [ "$RSYNCD_CONFIG" == "" -o ! -f "$RSYNCD_CONFIG" ]; then
        echo "rsync config not found."
        exit 11
    fi
    if [ "$SSH_IDENTITY" == "" -o ! -f "$SSH_IDENTITY" ]; then
        echo "SSH identity file not found."
        exit 12
    fi
    if [ "$REMOTE_HOST" == "" ]; then
        echo "No remote host set."
        exit 13
    fi
    if [ "$REMOTE_LOGIN" == "" ]; then
        echo "No remote login set."
        exit 14
    fi
    if [ "$REMOTE_PORT" == "" ];  then
        echo "remote port not set."
        exit 15
    fi
    if [ "$REMOTE_SOURCE" == "" ];  then
        echo "remote source not set."
        exit 16
    fi
    if [ "$REMOTE_TARGET" == "" ];  then
        echo "remote target not set."
        exit 17
    fi

    echo -e "\nSynchronisiere mit $REMOTE_HOST..."
    rsync --daemon --no-detach --config=$RSYNCD_CONFIG &
    pid=$!
    ssh -p $REMOTE_PORT -l $REMOTE_LOGIN -i $SSH_IDENTITY $REMOTE_HOST rsync -avzH --delete $REMOTE_SOURCE $REMOTE_TARGET
    kill $pid
    sleep 5
    kill -9 $pid
}

sshconsole() {
    if [ "$SSH_IDENTITY" == "" -o ! -f "$SSH_IDENTITY" ]; then
        echo "SSH identity file not found."
        exit 12
    fi
    if [ "$REMOTE_HOST" == "" ]; then
        echo "No remote host set."
        exit 13
    fi
    if [ "$REMOTE_LOGIN" == "" ]; then
        echo "No remote login set."
        exit 14
    fi
    if [ "$REMOTE_PORT" == "" ];  then
        echo "remote port not set."
        exit 15
    fi

    ssh -p $REMOTE_PORT -l $REMOTE_LOGIN -i $SSH_IDENTITY $REMOTE_HOST
}


_mount

if [ "$1" = "local" ]; then
    echo "Starte tägliches Backup..."
    localbackup
fi
if [ "$1" = "local+remote" ]; then
    echo "Starte Wöchentliches Backup..."
    localbackup
    sshbackup
fi
if [ "$1" = "remote" ]; then
    sshbackup
fi
if [ "$1" = "remoteconsole" ]; then
    sshconsole
fi
_umount
