#!/bin/bash
source secrets

# VPS details
VPS_IP="$SECRET_VPS_IP"
VPS_USER="$SECRET_VPS_USER"
SSH_KEY="$SECRET_SSH_KEY"

# Files on VPS
NGINX_CONF="/home/$VPS_USER/minecraft-proxy/nginx.conf"
DOCKER_COMPOSE_DIR="/home/$VPS_USER/minecraft-proxy"

# Local Files
SCRIPT_DIR="/users/Chris/minecraft-proxy-updater"

# Log file
LOG_FILE="$SCRIPT_DIR/minecraft-proxy-updater.log"
IP_FILE="$SCRIPT_DIR/current-ip"

# Function to log messages
log_message() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Get current public IPv4 address with validation
get_public_ip() {
  local ip=""

  # Try multiple IP detection services for redundancy
  for service in "https://api.ipify.org" "https://ipv4.icanhazip.com" "https://v4.ident.me"; do
    ip=$(curl -s -4 "$service")

    # Validate IP format with regex
    if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      echo "$ip"
      return 0
    fi
  done

  # If we get here, all services failed
  return 1
}

# Store the last known IP
if [ -f "$IP_FILE" ]; then
  LAST_IP=$(cat $IP_FILE)
else
  LAST_IP=""
  mkdir -p "$(dirname "$IP_FILE")" 2>/dev/null
  touch "$IP_FILE"
fi

# Get and validate the current IP
NEW_IP=$(get_public_ip)

# Check if we got a valid IP
if [ -z "$NEW_IP" ]; then
  log_message "ERROR: Failed to get a valid public IP address. Aborting update."
  exit 1
fi

# Log the current status
log_message "Current public IP: $NEW_IP, Last known IP: $LAST_IP"

# If IP has changed, update the VPS configuration
if [ "$NEW_IP" != "$LAST_IP" ]; then
  log_message "IPv4 changed from $LAST_IP to $NEW_IP"

  # Create a temporary file with the updated config
  TEMP_CONF=$(mktemp)

  # First backup the existing config
  ssh -i $SSH_KEY $VPS_USER@$VPS_IP "cp $NGINX_CONF ${NGINX_CONF}.bak" || {
    log_message "ERROR: Failed to create backup on VPS. Aborting."
    exit 1
  }

  # Download the current config
  scp -i $SSH_KEY $VPS_USER@$VPS_IP:$NGINX_CONF $TEMP_CONF || {
    log_message "ERROR: Failed to download current config from VPS."
    rm -f $TEMP_CONF
    exit 1
  }

  # Update the config locally with careful pattern matching
  # This updates "proxy_pass IP:PORT" to "proxy_pass NEW_IP:PORT"
  sed -i -E "s/proxy_pass ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+|)(:([0-9]+));/proxy_pass $NEW_IP\2;/g" $TEMP_CONF

  # Upload the updated config
  scp -i $SSH_KEY $TEMP_CONF $VPS_USER@$VPS_IP:$NGINX_CONF || {
    log_message "ERROR: Failed to upload updated config to VPS."
    rm -f $TEMP_CONF
    exit 1
  }

  # Clean up temp file
  rm -f $TEMP_CONF

  # Restart the container on VPS
  ssh -i $SSH_KEY $VPS_USER@$VPS_IP "cd $DOCKER_COMPOSE_DIR && docker-compose down && docker-compose up -d" || {
    log_message "ERROR: Failed to restart Docker containers on VPS."
    exit 1
  }

  # Save the new IP locally only if everything succeeded
  echo $NEW_IP >$IP_FILE
  log_message "Successfully updated VPS configuration and restarted proxy"
else
  log_message "IPv4 unchanged ($NEW_IP)"
fi

exit 0
