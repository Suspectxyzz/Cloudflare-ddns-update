#!/bin/bash
set -euo pipefail

# ====================================
# Cloudflare DDNS - Automatizat
# ====================================
CF_API_TOKEN="PASTE_YOUR_API_TOKEN_HERE"   # Token cu permisiunea Edit zone DNS
ZONE_ID="PASTE_YOUR_ZONE_ID_HERE"         # Zone ID pentru domeniul tău
ROOT_DOMAIN="mydomain.com"
SUBDOMAINS=("mydomain.com" "*" "api.mydomain.com" "etc" "etc")

CF_API="https://api.cloudflare.com/client/v4"
LOG_FILE="/var/log/cloudflare_ddns.log"
MAX_LOG_SIZE=$((100 * 1024 * 1024)) # 100 MB

# --- FUNCTII ---
get_public_ip() {
    curl -s https://ipv4.icanhazip.com | tr -d ' \n'
}

get_record_info() {
    local RECORD_NAME=$1
    curl -s -X GET "${CF_API}/zones/${ZONE_ID}/dns_records?type=A&name=${RECORD_NAME}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json"
}

create_record() {
    local RECORD_NAME=$1
    local NEW_IP=$2
    curl -s -X POST "${CF_API}/zones/${ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${RECORD_NAME}\",\"content\":\"${NEW_IP}\",\"ttl\":1,\"proxied\":false}" \
        >/dev/null
}

update_dns_record() {
    local RECORD_ID=$1
    local RECORD_NAME=$2
    local NEW_IP=$3
    curl -s -X PUT "${CF_API}/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${RECORD_NAME}\",\"content\":\"${NEW_IP}\",\"ttl\":1,\"proxied\":false}" \
        >/dev/null
}

log_change() {
    local SUBDOMAIN=$1
    local OLD_IP=$2
    local NEW_IP=$3
    local TIMESTAMP
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$TIMESTAMP | $SUBDOMAIN | $OLD_IP → $NEW_IP" >> "$LOG_FILE"
}

rotate_log() {
    if [[ -f "$LOG_FILE" && $(stat -c%s "$LOG_FILE") -ge $MAX_LOG_SIZE ]]; then
        mv "$LOG_FILE" "${LOG_FILE}.old"
        touch "$LOG_FILE"
    fi
}

# --- MAIN ---
rotate_log
CURRENT_IP=$(get_public_ip)
[[ -z "$CURRENT_IP" ]] && { echo "❌ Could not obtain public IP"; exit 1; }

for SUBDOMAIN in "${SUBDOMAINS[@]}"; do
    RECORD_NAME="$SUBDOMAIN"
    [[ "$SUBDOMAIN" == "*" ]] && RECORD_NAME="*.${ROOT_DOMAIN}"
    [[ "$SUBDOMAIN" == "$ROOT_DOMAIN" ]] && RECORD_NAME="$ROOT_DOMAIN"

    RECORD_INFO=$(get_record_info "$RECORD_NAME")
    RECORD_ID=$(echo "$RECORD_INFO" | jq -r '.result[0].id // empty')
    RECORD_IP=$(echo "$RECORD_INFO" | jq -r '.result[0].content // empty')

    if [[ -z "$RECORD_ID" ]]; then
        create_record "$RECORD_NAME" "$CURRENT_IP"
        log_change "$RECORD_NAME" "none" "$CURRENT_IP"
    elif [[ "$RECORD_IP" != "$CURRENT_IP" ]]; then
        update_dns_record "$RECORD_ID" "$RECORD_NAME" "$CURRENT_IP"
        log_change "$RECORD_NAME" "$RECORD_IP" "$CURRENT_IP"
    fi
done
