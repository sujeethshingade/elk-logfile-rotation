
# Overview

This project includes four files:

1. `docker-compose.yaml`: file that sets up four services: elasticsearch, kibana, logstash, and log-generator.
2. `logstash.conf`: for logstash that tells logstash how to handle the incoming data.
3. `log-generator.sh`: a shell script that generates random log messages in JSON format and sends them to the logstash service.
4. `Dockerfile`: a file used to build the log-generator service.

### Running the services

Make sure that you have Docker and Docker-compose installed on your machine.

Navigate to the directory where the files are located in your terminal.
Run the following command:

`docker-compose up`

### Stopping the services

`docker-compose down`

#### Navigate to Logs

`http://localhost:5601/`
`http://localhost:9200/`


### File-based Log Rotation (Logstash)

The Logstash configuration (`logstash/pipeline/logstash.conf`) implements file rotation:

```
file {
  path => "/usr/share/logstash/logs/flask-logs.log"
  codec => json_lines
  max_file_size => "1GB"
  max_file_age => "1d"
  archive => true
  archive_path => "/usr/share/logstash/logs/archived/flask-logs-%{+YYYY-MM-dd}.zip"
  archive_zip => true
  archive_zip_level => 9
  archive_zip_cleanup => true
  archive_zip_cleanup_age => "30d"
}
```

This configuration:

- Creates log files up to 1GB in size (rotates when this size is reached)
- Archives old logs into dated ZIP files (`flask-logs-YYYY-MM-DD.zip`)
- Applies ZIP compression level 9 (maximum compression)
- Automatically deletes archives older than 30 days
