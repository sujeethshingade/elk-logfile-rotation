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
    # NO prerotate - it was causing issues
    compress
    compresscmd /usr/bin/zip
    uncompresscmd /usr/bin/unzip
    compressext .zip
    compressoptions -9 
    olddir /usr/share/logstash/logs/archived
    create 0644 logstash logstash
    postrotate
        # Archive with timestamp directly (simpler process)
        cp /usr/share/logstash/logs/flask-logs.log.1 /usr/share/logstash/logs/archived/flask-logs\$(date +-%Y%m%d-%H%M%S).log
        # Zip the file properly
        cd /usr/share/logstash/logs/archived
        for f in *.log; do
            if [ -f "\$f" ] && [ ! -f "\$f.zip" ]; then
                zip -9 "\$f.zip" "\$f" && rm "\$f"
            fi
        done
        # Clean up old files
        find /usr/share/logstash/logs/archived -name "*.zip" -type f -mtime +30 -delete
        echo "Log rotated at \$(date) - Size trigger" >> /var/log/logrotate-execution.log
    endscript
}
EOF

# Set up cron job to run logrotate every minute (for testing)
echo "* * * * * /usr/sbin/logrotate -v /etc/logrotate.d/logstash >> /var/log/logrotate.log 2>&1" > /etc/cron.d/logrotate-logstash
chmod 0644 /etc/cron.d/logrotate-logstash

# Add a manual rotation script that can be run on-demand
cat > /usr/local/bin/rotate-logs-now.sh << 'EOF'
#!/bin/bash
echo "Running manual log rotation..."
/usr/sbin/logrotate -vf /etc/logrotate.d/logstash
echo "Done. Check /var/log/logrotate.log for results."
EOF
chmod +x /usr/local/bin/rotate-logs-now.sh

# Create log directories for tracking rotations
mkdir -p /var/log/logrotate
touch /var/log/logrotate.log
touch /var/log/logrotate-execution.log

# Add a background process to monitor log size and force rotation if needed
cat > /usr/local/bin/monitor-log-size.sh << 'EOF'
#!/bin/bash
LOG_FILE="/usr/share/logstash/logs/flask-logs.log"
MAX_SIZE_BYTES=$((10 * 1024 * 1024)) # 10 MB

while true; do
  if [ -f "$LOG_FILE" ]; then
    FILE_SIZE=$(stat -c%s "$LOG_FILE")
    if [ $FILE_SIZE -gt $MAX_SIZE_BYTES ]; then
      echo "Log file size ($FILE_SIZE bytes) exceeds maximum ($MAX_SIZE_BYTES bytes), forcing rotation..." >> /var/log/logrotate-execution.log
      /usr/sbin/logrotate -vf /etc/logrotate.d/logstash >> /var/log/logrotate.log 2>&1
    fi
  fi
  sleep 10
done
EOF
chmod +x /usr/local/bin/monitor-log-size.sh

# Start cron daemon in background
service cron start

# Start the log size monitor in background
nohup /usr/local/bin/monitor-log-size.sh &

# Verify directory permissions
echo "Log directories setup:"
ls -la /usr/share/logstash/logs

# Return success
echo "Log rotation setup completed successfully"