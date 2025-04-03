#!/bin/bash

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch..."
until curl -s "http://elasticsearch:9200" > /dev/null; do
    sleep 5
done

# Create ILM policy
echo "Creating ILM policy..."
curl -X PUT "http://elasticsearch:9200/_ilm/policy/logs_policy" -H 'Content-Type: application/json' -d'
{
  "policy": {
    "phases": {
      "hot": {
        "actions": {
          "rollover": {
            "max_size": "10MB",
            "max_age": "1d"
          }
        }
      },
      "delete": {
        "min_age": "30d",
        "actions": {
          "delete": {}
        }
      }
    }
  }
}
'

# Create index template
echo "Creating index template..."
curl -X PUT "http://elasticsearch:9200/_index_template/logs_template" -H 'Content-Type: application/json' -d'
{
  "index_patterns": ["logs-*"],
  "template": {
    "settings": {
      "number_of_shards": 1,
      "number_of_replicas": 1,
      "index.lifecycle.name": "logs_policy",
      "index.lifecycle.rollover_alias": "logs"
    },
    "mappings": {
      "properties": {
        "container_id": { "type": "integer" },
        "random_number": { "type": "integer" },
        "app_name": { "type": "keyword" },
        "hostname": { "type": "keyword" },
        "ip": { "type": "keyword" },
        "log_level": { "type": "keyword" },
        "message": { "type": "text" },
        "method": { "type": "keyword" },
        "path": { "type": "keyword" },
        "parameters": { "type": "keyword" },
        "request_url": { "type": "keyword" },
        "server_name": { "type": "keyword" },
        "username": { "type": "keyword" }
      }
    }
  }
}
'

echo "Elasticsearch ILM setup completed"