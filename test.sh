#!/bin/bash

echo "==============================================="
echo "          ELK LOG ROTATION CHECK TOOL          "
echo "==============================================="

# Get the logstash container ID
LOGSTASH_CONTAINER=$(docker ps | grep logstash | awk '{print $1}')
if [ -z "$LOGSTASH_CONTAINER" ]; then
  echo "❌ ERROR: Logstash container not found! Is it running?"
  exit 1
fi
echo "🔍 Using Logstash Container: $LOGSTASH_CONTAINER"

echo -e "\n===== FILE-BASED LOG ROTATION ====="
echo -e "\n📄 Current Log File:"
docker exec $LOGSTASH_CONTAINER bash -c "ls -lh /usr/share/logstash/logs/flask-logs.log || echo 'File not found'"

echo -e "\n📁 Archived Log Files:"
docker exec $LOGSTASH_CONTAINER bash -c "ls -lah /usr/share/logstash/logs/archived/ || echo 'No archives found.'"

echo -e "\n📋 Rotation Execution Log:"
docker exec $LOGSTASH_CONTAINER bash -c "cat /var/log/logrotate-execution.log || echo 'No execution log found.'"

echo -e "\n📋 Logrotate Status Log:"
docker exec $LOGSTASH_CONTAINER bash -c "tail -n 20 /var/log/logrotate.log || echo 'No logrotate log found.'"

echo -e "\n===== ELASTICSEARCH INDEX ROTATION ====="

echo -e "\n📊 Elasticsearch Indices:"
curl -s -X GET "http://localhost:9200/_cat/indices?v" || echo "Could not connect to Elasticsearch"

echo -e "\n🔄 ILM Explain (Current Status):"
curl -s -X POST "http://localhost:9200/_ilm/explain?pretty" | head -n 30

echo -e "\n=====================================================\n"

echo "Would you like to trigger a manual log rotation for testing? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Triggering manual log rotation..."
  docker exec $LOGSTASH_CONTAINER bash -c "logrotate -vf /etc/logrotate.d/logstash"
  echo "Done. Please check the logs above again to see the changes."
fi