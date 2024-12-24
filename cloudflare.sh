#!/bin/bash

# Cloudflare API credentials
EMAIL="admin@gmail.com" # Email Cloudflare.
KEY="" # Global API Key.
ZONE_ID="" # Zone ID API.
SUBDOMAINS=("cloudflare.com" "api.cloudflare.com" "etc.cloudflare.com") # Add multiple subdomains here, separated by spaces.
#SUBDOMAINS=("cloudflare.com") # If you only want to update one domain/subdomain, leave only one.

# Function to get the public IP address
get_public_ip() {
    curl -s https://api.ipify.org
}

# Function to get the DNS record ID and IP for the specified record name
get_record_info() {
    local ZONE_ID=$1
    local RECORD_NAME=$2

    RECORD_INFO=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME" \
        -H "X-Auth-Email: $EMAIL" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/json")

    RECORD_ID=$(echo $RECORD_INFO | jq -r '.result[0].id')
    RECORD_IP=$(echo $RECORD_INFO | jq -r '.result[0].content')
}

# Function to update the DNS record with the new IP address
update_dns_record() {
    local ZONE_ID=$1
    local RECORD_ID=$2
    local RECORD_NAME=$3
    local NEW_IP=$4

    curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "X-Auth-Email: $EMAIL" \
        -H "X-Auth-Key: $KEY" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$NEW_IP\",\"ttl\":1,\"proxied\":false}" \
        | jq
}

# Get the current public IP
CURRENT_IP=$(get_public_ip)

# Iterate through the list of subdomains and update each one
for SUBDOMAIN in "${SUBDOMAINS[@]}"; do
    get_record_info $ZONE_ID $SUBDOMAIN
    if [ "$CURRENT_IP" != "$RECORD_IP" ]; then
        echo "Updating DNS record for $SUBDOMAIN from $RECORD_IP to $CURRENT_IP"
        update_dns_record $ZONE_ID $RECORD_ID $SUBDOMAIN $CURRENT_IP
    else
        echo "The IP address for $SUBDOMAIN has not changed. No update needed."
    fi
done
