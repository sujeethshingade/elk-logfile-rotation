#!/bin/bash

echo "=== Checking Time-Based Rotation ==="
echo "Current time-based indices:"
curl -s -X GET "localhost:9200/_cat/indices/flask-logs-*?v"

echo -e "\n=== Checking ILM Rotation ==="
echo "ILM Policy Status:"
curl -s -X GET "localhost:9200/_ilm/policy/logs_policy" | jq '.'

echo -e "\nRollover Status:"
curl -s -X GET "localhost:9200/logs/_alias" | jq '.'

echo -e "\nILM Execution Status:"
curl -s -X GET "localhost:9200/_ilm/explain/logs" | jq '.'

echo -e "\n=== Checking Index Statistics ==="
echo "Document counts and sizes:"
curl -s -X GET "localhost:9200/_cat/indices/logs-*?v&h=index,health,status,pri,rep,count,store.size" 