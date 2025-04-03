#!/bin/bash

# Install required packages
apt-get update && apt-get install -y logrotate cron zip unzip

# Create log directories with proper ownership and permissions
mkdir -p /usr/share/logstash/logs/archived
touch /usr/share/logstash/logs/flask-logs.log

# Set proper ownership and permissions
chown -R logstash:logstash /usr/share/logstash/logs
chmod -R 755 /usr/share/logstash/logs
chmod 644 /usr/share/logstash/logs/flask-logs.log

# Create logrotate config
cat > /etc/logrotate.d/logstash << EOF
/usr/share/logstash/logs/flask-logs.log {
    size 10M
    missingok
    rotate 30
    dateext
    dateformat -%Y-%m-%d
    compress
    compresscmd /usr/bin/zip
    uncompresscmd /usr/bin/unzip
    compressext .zip
    olddir /usr/share/logstash/logs/archived
    compressoptions -9 
    create 0644 logstash logstash
    postrotate
        find /usr/share/logstash/logs/archived -name "*.zip" -type f -mtime +30 -delete
    endscript
}
EOF

# Set up cron job to run logrotate every minute
echo "* * * * * /usr/sbin/logrotate -f /etc/logrotate.d/logstash > /var/log/logrotate.log 2>&1" > /etc/cron.d/logrotate-logstash
chmod 0644 /etc/cron.d/logrotate-logstash

# Start cron daemon in background
service cron start

# Verify directory permissions (debugging)
ls -la /usr/share/logstash/logs

# Return success
echo "Log rotation setup completed"