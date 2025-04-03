#!/bin/bash

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch..."
until curl -s "http://elasticsearch:9200" > /dev/null; do
    sleep 5
done

# Create ILM policy with more aggressive rotation for testing
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
          },
          "set_priority": {
            "priority": 100
          }
        }
      },
      "warm": {
        "min_age": "2d",
        "actions": {
          "set_priority": {
            "priority": 50
          },
          "forcemerge": {
            "max_num_segments": 1
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
        "username": { "type": "keyword" },
        "rotation_tag": { "type": "keyword" }
      }
    }
  }
}
'

# Create initial index
echo "Creating initial index..."
curl -X PUT "http://elasticsearch:9200/%3Clogs-%7Bnow%2Fd%7D-000001%3E" -H 'Content-Type: application/json' -d'
{
  "aliases": {
    "logs": {
      "is_write_index": true
    }
  }
}
'

echo "Elasticsearch ILM setup completed"