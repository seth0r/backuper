#!/bin/bash

export configdir=/config
export backupdir=/backup
export sourcedir=/tobackup

datecmd="date +%u"

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

daybackup() {
    mkdir -p "$backupdir/local"

    bname=`$datecmd`
    tmp=`ls -l $backupdir/local/current | awk '{print $11}'`
    tmp=`basename $tmp`
    if [ "$tmp" != "$bname" ]; then
        mkdir -p $backupdir/local/$bname
        rm -rf $backupdir/local/$bname/*
        cp -rpl $backupdir/local/current/* $backupdir/local/$bname/ > /dev/null 2> /dev/null
    fi

    date

#    mysqlbackup

#    mongodump --out $backupdir/local/$weekday/mongodb.dump
#    tar -cjpf $backupdir/local/$weekday/mongodb.dump.tar.bz2 $backupdir/local/$weekday/mongodb.dump
#    rm -r $backupdir/local/$weekday/mongodb.dump

    for d in $sourcedir/*; do
        name=`basename $d`
        opts="-avxWH --safe-links --delete"
        if [ -f "$configdir/$name.options" ] ; then
            cat "$configdir/$name.options" | while read line; do
            opts="$opts $line"
            done
        fi
        if [ -f "$configdir/$name.exclude" ] ; then
            opts="$opts --exclude-from='$configdir/$name.exclude' --delete-excluded"
        fi
        mkdir -p "$backupdir/local/$bname/$name"
        echo "Synchronisiere lokal $name..."
        echo "nice -n 18 rsync $opts \"$d/\" \"$backupdir/local/$bname/$name/\""
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
    mkdir -p "$backupdir/encfs"

    rm -f $backupdir/sshbackup.log
    rm -f $backupdir/sshbackup.err

    (

        date
        date >&2

        if [ -f "$backupdir/temp/.encfs6.xml" ]; then
            echo "Lade EncFS..."
            cat "$backupdir/password" | encfs "$backupdir/temp" "$backupdir/encfs" -S 
            if [ $? -eq 0 ]; then
                nice -n 18 rsync -avWH --delete "$backupdir/local/current/" "$backupdir/encfs"

                echo -e "\nSynchronisiere mit sanguin17.selfhost.eu..."
#                echo -e "\nSynchronisiere mit helmchyn.no-ip.biz..."
                rsync --daemon --no-detach --config=/data/scripts/rsyncd.conf &
                pid=$!
                ssh -p 58072 sven@sanguin17.selfhost.eu rsync -avzH --delete rsync://seth0r.net:60077/backup/ ./backup/
#                ssh seth0r@helmchyn.no-ip.biz rsync -azH --delete rsync://seth0r.net:60077/backup/ ./backup/
                kill $pid
                sleep 5
                kill -9 $pid
                echo
                rm -rf "$backupdir/encfs/"*
                sleep .1
                umount "$backupdir/encfs"
            fi
        else
            echo "Kein EncFS gefunden!"
        fi

    ) >>$backupdir/sshbackup.log 2>>$backupdir/sshbackup.err

    echo
    echo "######################################################"
    tail -n 100 $backupdir/sshbackup.log
    echo "######################################################"
}

if [ -d "$backupdir/local" ]; then
    if [ "$1" = "day" ]; then
        echo "Starte tägliches Backup..."
        daybackup
    fi
    if [ "$1" = "week" ]; then
        echo "Starte Wöchentliches Backup..."
        daybackup
        sshbackup
    fi
    if [ "$1" = "ssh" ]; then
        sshbackup
    fi
else
    echo "$backupdir not mounted."
fi
wait
