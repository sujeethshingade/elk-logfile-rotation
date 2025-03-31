#!/bin/bash

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch to be ready..."
until curl -s http://localhost:9200 > /dev/null; do
    sleep 1
done

# Create ILM policy
echo "Creating ILM policy..."
curl -X PUT "http://localhost:9200/_ilm/policy/logs_policy" \
     -H "Content-Type: application/json" \
     -d @templates/ilm_policy.json

# Create index template
echo "Creating index template..."
curl -X PUT "http://localhost:9200/_template/logs_template" \
     -H "Content-Type: application/json" \
     -d @templates/logs_template.json

# Create initial index
echo "Creating initial index..."
curl -X PUT "http://localhost:9200/logs-000001" \
     -H "Content-Type: application/json" \
     -d '{
       "aliases": {
         "logs": {
           "is_write_index": true
         }
       }
     }'

echo "Setup complete!" 