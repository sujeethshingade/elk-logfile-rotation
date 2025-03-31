#!/bin/bash

# Create export directory
mkdir -p elk_export

# Export indices using snapshot
echo "Creating snapshot repository..."
curl -X PUT "localhost:9200/_snapshot/my_backup" -H 'Content-Type: application/json' -d '{
  "type": "fs",
  "settings": {
    "location": "/usr/share/elasticsearch/backups"
  }
}'

echo "Creating snapshot..."
curl -X PUT "localhost:9200/_snapshot/my_backup/snapshot_1?wait_for_completion=true" -H 'Content-Type: application/json' -d '{
  "indices": "flask-logs-2025.03.21,logs,logs-2025.03.29"
}'

# Export logs from each index
echo "Exporting logs from flask-logs-2025.03.21..."
curl -X GET "localhost:9200/flask-logs-2025.03.21/_search?pretty" -H 'Content-Type: application/json' -d '{
  "query": {
    "match_all": {}
  },
  "size": 10000
}' > elk_export/flask_logs.json

echo "Exporting logs from logs (ILM)..."
curl -X GET "localhost:9200/logs/_search?pretty" -H 'Content-Type: application/json' -d '{
  "query": {
    "match_all": {}
  },
  "size": 10000
}' > elk_export/ilm_logs.json

echo "Exporting logs from logs-2025.03.29..."
curl -X GET "localhost:9200/logs-2025.03.29/_search?pretty" -H 'Content-Type: application/json' -d '{
  "query": {
    "match_all": {}
  },
  "size": 10000
}' > elk_export/time_based_logs.json

echo "Export complete! Files are in the elk_export directory." 