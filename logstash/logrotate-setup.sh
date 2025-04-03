#!/bin/bash

# Install required packages
apt-get update && apt-get install -y logrotate cron zip unzip findutils

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
    dateformat -%Y%m%d-%H%M%S
    compress
    compresscmd /usr/bin/zip
    uncompresscmd /usr/bin/unzip
    compressext .zip
    compressoptions -9 
    olddir /usr/share/logstash/logs/archived
    create 0644 logstash logstash
    postrotate
        find /usr/share/logstash/logs/archived -name "*.zip" -type f -mtime +30 -delete
        echo "Log rotated at \$(date) - Size trigger" >> /var/log/logrotate-execution.log
    endscript
}
EOF

# Make logrotate config more aggressive for testing purposes
echo 'include /etc/logrotate.d' > /etc/logrotate.conf
echo 'rotate 30' >> /etc/logrotate.conf
echo 'compress' >> /etc/logrotate.conf

# Set up cron job to run logrotate every minute (for testing)
echo "* * * * * /usr/sbin/logrotate -f /etc/logrotate.d/logstash >> /var/log/logrotate.log 2>&1" > /etc/cron.d/logrotate-logstash
chmod 0644 /etc/cron.d/logrotate-logstash

# Create a log cleanup script
cat > /usr/local/bin/cleanup-old-logs.sh << 'EOF'
#!/bin/bash
find /usr/share/logstash/logs/archived -name "*.zip" -type f -mtime +30 -delete
echo "Cleanup script ran at $(date)" >> /var/log/logrotate-cleanup.log
EOF

chmod +x /usr/local/bin/cleanup-old-logs.sh

# Add daily log cleanup job
echo "0 0 * * * /usr/local/bin/cleanup-old-logs.sh" > /etc/cron.d/cleanup-logs
chmod 0644 /etc/cron.d/cleanup-logs

# Create log directories for tracking rotations
mkdir -p /var/log/logrotate
touch /var/log/logrotate.log
touch /var/log/logrotate-execution.log
touch /var/log/logrotate-cleanup.log

# Start cron daemon in background
service cron start

# Verify directory permissions
echo "Log directories setup:"
ls -la /usr/share/logstash/logs

# Return success
echo "Log rotation setup completed successfully"