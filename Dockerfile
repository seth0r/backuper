FROM ubuntu:20.04
MAINTAINER me+docker@seth0r.net

RUN apt-get update 
RUN apt-get dist-upgrade -y
RUN apt-get -y install cron rsync openssh-client mysql-client mongodb-clients vim gpg wget python3.7 gnupg2 curl docker.io


RUN wget -q https://repos.influxdata.com/influxdata-archive_compat.key
RUN echo '393e8779c89ac8d958f81f942f9ad7fb82a25e133faddaf92e15b16e6ac9ce4c influxdata-archive_compat.key' | sha256sum -c && cat influxdata-archive_compat.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg > /dev/null
RUN echo 'deb [signed-by=/etc/apt/trusted.gpg.d/influxdata-archive_compat.gpg] https://repos.influxdata.com/debian stable main' | tee /etc/apt/sources.list.d/influxdata.list

RUN apt-get update 
RUN apt-get install -y influxdb

#RUN apt-get clean && \
#    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY backup.sh /usr/local/sbin/backup.sh
RUN chmod +x /usr/local/sbin/backup.sh

# Copy hello-cron file to the cron.d directory
COPY backup-cron /etc/cron.d/backup-cron

# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/backup-cron

# Apply cron job
RUN crontab /etc/cron.d/backup-cron

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Run the command on container startup
CMD cron && tail -f /var/log/cron.log
