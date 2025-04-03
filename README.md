# ELK Stack with Log Rotation

This project implements a complete ELK (Elasticsearch, Logstash, Kibana) stack with log rotation capabilities based on size (10MB), compression (ZIP), and 30-day retention.

## Overview

The project includes:

1. `docker-compose.yaml`: Sets up five services: elasticsearch, kibana, logstash, es-setup, and flask-app.
2. `logstash/pipeline/logstash.conf`: Configures logstash to process incoming logs and output to files.
3. `logstash/logrotate-setup.sh`: Implements file-based log rotation using logrotate.
4. `elasticsearch/setup-ilm.sh`: Configures Elasticsearch Index Lifecycle Management for index rotation.
5. `app.py`: Flask application that generates logs with configurable sizes.

## Log Rotation Implementation

This project implements log rotation at two levels:

### 1. File-based Log Rotation (logrotate)

The system uses logrotate to manage log files with these specifications:
- Rotates logs when they reach 10MB
- Compresses using ZIP format with maximum compression level
- Stores in dated archive files
- Automatically deletes logs older than 30 days

```
/usr/share/logstash/logs/flask-logs.log {
    size 10M
    missingok
    rotate 30
    dateext
    dateformat -%Y%m%d-%H%M%S
    compress
    compresscmd /usr/bin/zip
    compressext .zip
    compressoptions -9 
    olddir /usr/share/logstash/logs/archived
    create 0644 logstash logstash
    postrotate
        find /usr/share/logstash/logs/archived -name "*.zip" -type f -mtime +30 -delete
    endscript
}
```

### 2. Elasticsearch Index Lifecycle Management

Elasticsearch indices are managed with ILM policies:
- Rolls over indices when they reach 10MB or 1 day old
- Deletes indices older than 30 days

## Testing Log Rotation

### Generating Test Logs

The application includes features to generate logs of various sizes for testing:

1. In the web interface, navigate to http://localhost:8080
2. Use the buttons to generate logs:
   - Generate 10MB Logs
   - Generate 100MB Logs
   - Generate 1000MB Logs

### Verifying Log Rotation

Once logs are generated, you can verify rotation works:

1. Connect to the logstash container:
   ```
   docker exec -it <logstash-container-id> bash
   ```

2. Check the logs directory to see rotated logs:
   ```
   ls -la /usr/share/logstash/logs/archived/
   ```

3. The files should follow the naming pattern `flask-logs-YYYYMMDD-HHMMSS.zip`

## Running the services

Make sure that you have Docker and Docker-compose installed.

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Access the interfaces

- Kibana: http://localhost:5601
- Elasticsearch: http://localhost:9200
- Log Generator UI: http://localhost:8080