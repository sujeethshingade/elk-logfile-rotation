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
    # Important: Copy the file before compression to preserve extension
    prerotate
        cp /usr/share/logstash/logs/flask-logs.log /usr/share/logstash/logs/flask-logs.log.bak
    endscript
    compress
    compresscmd /usr/bin/zip
    uncompresscmd /usr/bin/unzip
    compressext .zip
    compressoptions -9 
    olddir /usr/share/logstash/logs/archived
    create 0644 logstash logstash
    postrotate
        # Move backup to archive with .log extension preserved
        mv /usr/share/logstash/logs/flask-logs.log.bak /usr/share/logstash/logs/archived/flask-logs\$(date +-%Y%m%d-%H%M%S).log
        # Zip the file properly to ensure .log extension is preserved
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

# Make logrotate config more aggressive for testing purposes
echo 'include /etc/logrotate.d' > /etc/logrotate.conf
echo 'rotate 30' >> /etc/logrotate.conf
echo 'compress' >> /etc/logrotate.conf

# Set up cron job to run logrotate every minute (for testing)
echo "* * * * * /usr/sbin/logrotate -f /etc/logrotate.d/logstash >> /var/log/logrotate.log 2>&1" > /etc/cron.d/logrotate-logstash
chmod 0644 /etc/cron.d/logrotate-logstash

# Create a log extraction helper script
cat > /usr/local/bin/extract-logs.sh << 'EOF'
#!/bin/bash
# Script to extract and view rotated logs

ARCHIVE_DIR="/usr/share/logstash/logs/archived"
EXTRACT_DIR="/tmp/extracted_logs"

mkdir -p $EXTRACT_DIR

echo "Available log archives:"
ls -la $ARCHIVE_DIR

echo ""
echo "Enter archive filename to extract (or 'all' to extract all):"
read FILENAME

if [ "$FILENAME" = "all" ]; then
  for f in $ARCHIVE_DIR/*.zip; do
    BASENAME=$(basename "$f")
    echo "Extracting $BASENAME..."
    unzip -o "$f" -d "$EXTRACT_DIR"
  done
else
  if [ -f "$ARCHIVE_DIR/$FILENAME" ]; then
    echo "Extracting $FILENAME..."
    unzip -o "$ARCHIVE_DIR/$FILENAME" -d "$EXTRACT_DIR"
  else
    echo "File not found!"
    exit 1
  fi
fi

echo ""
echo "Extracted logs:"
ls -la $EXTRACT_DIR

echo ""
echo "View a log? Enter filename (or 'exit' to quit):"
read LOGFILE

if [ "$LOGFILE" != "exit" ]; then
  if [ -f "$EXTRACT_DIR/$LOGFILE" ]; then
    cat "$EXTRACT_DIR/$LOGFILE" | jq '.' || cat "$EXTRACT_DIR/$LOGFILE"
  else
    echo "Log file not found!"
  fi
fi

echo "Done. Extracted logs are in $EXTRACT_DIR"
EOF
chmod +x /usr/local/bin/extract-logs.sh

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