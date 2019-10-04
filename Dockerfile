FROM ubuntu:18.04
MAINTAINER me+docker@seth0r.net

RUN apt-get update 
RUN apt-get dist-upgrade -y
RUN apt-get -y install cron python3 rsync mysql-client mongodb-clients

#RUN apt-get clean && \
#    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY backup.sh /usr/local/sbin/backup.sh
RUN chmod +x /usr/local/sbin/backup.sh

COPY printsizediff.py /usr/local/bin/printsizediff.py
RUN chmod +x /usr/local/bin/printsizediff.py

# Copy hello-cron file to the cron.d directory
#COPY hello-cron /etc/cron.d/hello-cron

# Give execution rights on the cron job
#RUN chmod 0644 /etc/cron.d/hello-cron

# Apply cron job
#RUN crontab /etc/cron.d/hello-cron

# Create the log file to be able to run tail
RUN touch /var/log/cron.log

# Run the command on container startup
CMD cron && tail -f /var/log/cron.log
