#!/bin/bash

# filepath: c:\Users\sures\Downloads\elk-trial\inspect-logs.sh
# Text formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Array to store log files
declare -a LOG_FILES

# Function to find the logstash container ID
get_logstash_container() {
  echo -e "${BLUE}Locating Logstash container...${NC}"
  LOGSTASH_CONTAINER=$(docker ps | grep logstash | awk '{print $1}')
  if [ -z "$LOGSTASH_CONTAINER" ]; then
    echo -e "${YELLOW}⚠️ No Logstash container found. Is it running?${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓ Found Logstash container: $LOGSTASH_CONTAINER${NC}"
}

# Function to view current log file
view_current_log() {
  echo -e "${BLUE}Fetching current log file info:${NC}"
  docker exec $LOGSTASH_CONTAINER bash -c "ls -lh /usr/share/logstash/logs/flask-logs.log"
  
  echo -e "\n${BLUE}Would you like to view the contents? (y/n)${NC}"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "${BLUE}Contents of current log file (last 20 lines):${NC}"
    docker exec $LOGSTASH_CONTAINER bash -c "tail -n 20 /usr/share/logstash/logs/flask-logs.log"
    
    echo -e "\n${BLUE}Would you like to see more lines? Enter number or 'n' to skip:${NC}"
    read -r lines
    if [[ "$lines" =~ ^[0-9]+$ ]]; then
      docker exec $LOGSTASH_CONTAINER bash -c "tail -n $lines /usr/share/logstash/logs/flask-logs.log"
    fi
  fi
}

# Function to list archived log files with numbering
list_archived_logs() {
  echo -e "${BLUE}Listing archived log files:${NC}"
  # Get the list of files and store in array
  LOG_FILES=()
  while IFS= read -r line; do
    if [[ -n "$line" && "$line" != "No archived logs found." ]]; then
      LOG_FILES+=("$line")
    fi
  done < <(docker exec $LOGSTASH_CONTAINER bash -c "find /usr/share/logstash/logs/archived/ -type f -printf '%f\n' 2>/dev/null || echo 'No archived logs found.'")
  
  if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No archived logs found.${NC}"
    return
  fi
  
  # Show detailed listing first
  docker exec $LOGSTASH_CONTAINER bash -c "ls -lah /usr/share/logstash/logs/archived/ || echo 'No archived logs found.'"
  
  echo -e "\n${BOLD}Available log files by number:${NC}"
  for i in "${!LOG_FILES[@]}"; do
    echo -e "${GREEN}[$((i+1))]${NC} ${LOG_FILES[$i]}"
  done
}

# Function to extract and view a specific archived log
view_archived_log() {
  list_archived_logs
  
  if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
    return
  fi
  
  echo -e "\n${BLUE}Enter the number or filename to view (or 'exit' to return):${NC}"
  read -r selection
  
  if [[ "$selection" == "exit" ]]; then
    return
  fi
  
  filename=""
  # Check if input is a number
  if [[ "$selection" =~ ^[0-9]+$ ]]; then
    if [[ $selection -gt 0 && $selection -le ${#LOG_FILES[@]} ]]; then
      filename="${LOG_FILES[$((selection-1))]}"
      echo -e "${GREEN}Selected: $filename${NC}"
    else
      echo -e "${YELLOW}Invalid number. Please select between 1 and ${#LOG_FILES[@]}.${NC}"
      return
    fi
  else
    # Input is a filename, check if it exists in array
    found=false
    for f in "${LOG_FILES[@]}"; do
      if [[ "$f" == "$selection" ]]; then
        found=true
        filename="$selection"
        break
      fi
    done
    
    if [[ "$found" == "false" ]]; then
      echo -e "${YELLOW}File not found: $selection${NC}"
      return
    fi
  fi
  
  echo -e "${BLUE}File contents:${NC}"
  if [[ "$filename" == *.zip ]]; then
    echo -e "${YELLOW}This is a ZIP file. Extracting and showing content...${NC}"
    docker exec $LOGSTASH_CONTAINER bash -c "mkdir -p /tmp/extracted && \
      rm -rf /tmp/extracted/* && \
      unzip -o /usr/share/logstash/logs/archived/$filename -d /tmp/extracted && \
      for file in \$(ls /tmp/extracted); do 
        # Ensure each extracted file has a .log extension
        base_name=\$(basename \"\$file\" .log)
        if [[ \"\$file\" != *\".log\"* ]]; then
          mv \"/tmp/extracted/\$file\" \"/tmp/extracted/\$base_name.log\"
          file=\"\$base_name.log\"
        fi
        echo \"=== \$file ===\" 
        cat \"/tmp/extracted/\$file\" | head -n 20
        echo \"\n[...truncated...]\"
      done"
  else
    docker exec $LOGSTASH_CONTAINER bash -c "cat /usr/share/logstash/logs/archived/$filename | head -n 20; echo \"\n[...truncated...]\""
  fi
}

# Function to save logs to host
export_logs() {
  echo -e "${BLUE}Select export option:${NC}"
  echo "1. Export current log"
  echo "2. Export specific archived log"
  echo "3. Export all archived logs"
  echo "4. Return to main menu"
  read -r choice
  
  EXPORT_DIR="./exported_logs"
  mkdir -p "$EXPORT_DIR"
  
  case $choice in
    1)
      echo -e "${BLUE}Exporting current log file...${NC}"
      docker cp $LOGSTASH_CONTAINER:/usr/share/logstash/logs/flask-logs.log "$EXPORT_DIR/flask-logs.log"
      ;;
    2)
      export_specific_archived_log
      ;;
    3)
      echo -e "${BLUE}Exporting all archived logs...${NC}"
      # Create a temp directory in the container, copy all files there, then extract to host
      docker exec $LOGSTASH_CONTAINER bash -c "mkdir -p /tmp/archive_export && \
        rm -rf /tmp/archive_export/* && \
        cp -r /usr/share/logstash/logs/archived/* /tmp/archive_export/ 2>/dev/null || echo 'No files to copy'"
      
      # Now process each zip file to ensure proper extensions
      docker exec $LOGSTASH_CONTAINER bash -c "cd /tmp/archive_export && \
        for zipfile in *.zip; do 
          if [ -f \"\$zipfile\" ]; then
            dirname=\$(basename \"\$zipfile\" .zip)
            mkdir -p \"\$dirname\"
            unzip -o \"\$zipfile\" -d \"\$dirname\"
            # Fix extensions in the extracted directory
            cd \"\$dirname\"
            for file in *; do
              if [[ \"\$file\" != *\".log\"* ]]; then
                mv \"\$file\" \"\$file.log\"
              fi
            done
            cd ..
            rm \"\$zipfile\"
          fi
        done"
      
      docker cp $LOGSTASH_CONTAINER:/tmp/archive_export "$EXPORT_DIR/archived"
      ;;
    4)
      return
      ;;
    *)
      echo -e "${YELLOW}Invalid option${NC}"
      ;;
  esac
  
  echo -e "${GREEN}✓ Files exported to $EXPORT_DIR${NC}"
  ls -la "$EXPORT_DIR"
}

# Function to export a specific archived log
export_specific_archived_log() {
  list_archived_logs
  
  if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
    return
  fi
  
  echo -e "${BLUE}Enter the number or filename to export:${NC}"
  read -r selection
  
  filename=""
  # Check if input is a number
  if [[ "$selection" =~ ^[0-9]+$ ]]; then
    if [[ $selection -gt 0 && $selection -le ${#LOG_FILES[@]} ]]; then
      filename="${LOG_FILES[$((selection-1))]}"
      echo -e "${GREEN}Selected: $filename${NC}"
    else
      echo -e "${YELLOW}Invalid number. Please select between 1 and ${#LOG_FILES[@]}.${NC}"
      return
    fi
  else
    # Input is a filename, check if it exists in array
    found=false
    for f in "${LOG_FILES[@]}"; do
      if [[ "$f" == "$selection" ]]; then
        found=true
        filename="$selection"
        break
      fi
    done
    
    if [[ "$found" == "false" ]]; then
      echo -e "${YELLOW}File not found: $selection${NC}"
      return
    fi
  fi
  
  echo -e "${BLUE}Exporting $filename...${NC}"
  
  # Create export dir if needed
  EXPORT_DIR="./exported_logs"
  mkdir -p "$EXPORT_DIR"
  
  if [[ "$filename" == *.zip ]]; then
    echo -e "${YELLOW}This is a ZIP file. Extracting with proper log extensions...${NC}"
    # Create temporary directory in the container
    docker exec $LOGSTASH_CONTAINER bash -c "mkdir -p /tmp/export_extract && \
      rm -rf /tmp/export_extract/* && \
      unzip -o /usr/share/logstash/logs/archived/$filename -d /tmp/export_extract && \
      for file in \$(ls /tmp/export_extract); do 
        # Ensure each extracted file has a .log extension
        base_name=\$(basename \"\$file\" .log)
        if [[ \"\$file\" != *\".log\"* ]]; then
          mv \"/tmp/export_extract/\$file\" \"/tmp/export_extract/\$base_name.log\"
        fi
      done"
    
    # Create target directory
    mkdir -p "$EXPORT_DIR/$(basename "$filename" .zip)"
    
    # Copy the extracted files to host
    docker cp $LOGSTASH_CONTAINER:/tmp/export_extract/. "$EXPORT_DIR/$(basename "$filename" .zip)/"
  else
    # For non-zip files, just copy directly
    docker cp $LOGSTASH_CONTAINER:/usr/share/logstash/logs/archived/$filename "$EXPORT_DIR/$filename"
  fi
}

# Function to check log rotation status
check_rotation_status() {
  echo -e "${BLUE}Checking log rotation configuration and status...${NC}"
  
  echo -e "\n${BOLD}1. Logrotate Configuration:${NC}"
  docker exec $LOGSTASH_CONTAINER bash -c "cat /etc/logrotate.d/logstash"
  
  echo -e "\n${BOLD}2. Logrotate Status:${NC}"
  docker exec $LOGSTASH_CONTAINER bash -c "cat /var/log/logrotate.log | tail -n 20 || echo 'No logrotate log found.'"
  
  echo -e "\n${BOLD}3. Rotation Execution Log:${NC}"
  docker exec $LOGSTASH_CONTAINER bash -c "cat /var/log/logrotate-execution.log || echo 'No execution log found.'"
  
  echo -e "\n${BOLD}4. Current Log Size:${NC}"
  docker exec $LOGSTASH_CONTAINER bash -c "du -h /usr/share/logstash/logs/flask-logs.log"
  
  echo -e "\n${BOLD}5. Elasticsearch ILM Status:${NC}"
  curl -s -X GET "http://localhost:9200/_cat/indices?v" | grep logs
  curl -s -X POST "http://localhost:9200/_ilm/explain?pretty" | head -n 30
}

# Function to trigger manual log rotation
trigger_rotation() {
  echo -e "${YELLOW}Warning: This will force rotate the logs for testing purposes.${NC}"
  echo -e "${BLUE}Proceed? (y/n)${NC}"
  read -r response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo -e "${BLUE}Triggering manual log rotation...${NC}"
    docker exec $LOGSTASH_CONTAINER bash -c "logrotate -vf /etc/logrotate.d/logstash"
    echo -e "${GREEN}✓ Rotation triggered. Check status to verify.${NC}"
  fi
}

# Main menu function
show_menu() {
  echo -e "\n${BOLD}${GREEN}==== ELK LOG ROTATION INSPECTOR ====${NC}"
  echo "1. View current log file"
  echo "2. List archived log files"
  echo "3. View specific archived log"
  echo "4. Export logs to host system"
  echo "5. Check log rotation status"
  echo "6. Trigger manual log rotation"
  echo "7. Exit"
  echo -e "${BLUE}Enter choice [1-7]:${NC}"
}

# Main script execution
get_logstash_container

while true; do
  show_menu
  read -r choice
  
  case $choice in
    1) view_current_log ;;
    2) list_archived_logs ;;
    3) view_archived_log ;;
    4) export_logs ;;
    5) check_rotation_status ;;
    6) trigger_rotation ;;
    7) 
      echo -e "${GREEN}Exiting. Goodbye!${NC}"
      exit 0
      ;;
    *)
      echo -e "${YELLOW}Invalid option. Please try again.${NC}"
      ;;
  esac
  
  echo -e "\n${BLUE}Press Enter to continue...${NC}"
  read -r
done