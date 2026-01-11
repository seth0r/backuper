FROM debian:trixie-slim
MAINTAINER me+docker@seth0r.net

RUN apt-get update 
RUN apt-get dist-upgrade -y
RUN apt-get -y install cron rsync openssh-client mariadb-client vim gpg wget python3 gnupg2 curl docker.io

RUN if [ "$( dpkg --print-architecture )" = "arm64" ]; then \
        wget -O mongodb-database-tools.deb https://fastdl.mongodb.org/tools/db/mongodb-database-tools-ubuntu2404-arm64-100.12.2.deb ; \
    else \
        wget -O mongodb-database-tools.deb https://fastdl.mongodb.org/tools/db/mongodb-database-tools-debian12-x86_64-100.12.2.deb ; \
    fi && dpkg -i mongodb-database-tools.deb && rm mongodb-database-tools.deb

RUN wget -q https://repos.influxdata.com/influxdata-archive.key
RUN gpg --show-keys --with-fingerprint --with-colons ./influxdata-archive.key 2>&1 | grep -q '^fpr:\+24C975CBA61A024EE1B631787C3D57159FC2F927:$' && cat influxdata-archive.key | gpg --dearmor | tee /etc/apt/keyrings/influxdata-archive.gpg > /dev/null
RUN echo 'deb [signed-by=/etc/apt/keyrings/influxdata-archive.gpg] https://repos.influxdata.com/debian stable main' | tee /etc/apt/sources.list.d/influxdata.list

RUN apt-get install -y postgresql-common && /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y

RUN apt-get update 
RUN apt-get install -y influxdb postgresql-client

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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
