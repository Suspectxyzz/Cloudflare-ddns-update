#!/bin/bash
set -euo pipefail

# ====================================
# Cloudflare DDNS - Secure Mode
# =====================================
# Config:
# 1️⃣ Create a limited API Token in the Cloudflare Dashboard:
# - https://dash.cloudflare.com/profile/api-tokens
# - Template: "Edit zone DNS"
# - Permissions: Zone → DNS → Edit
# - Zone Resources: Include → Specific zone → lry.ro
# 2️⃣ Save it as a permanent environment variable:
# echo 'export CF_API_TOKEN="eyJhbGciOi..."' >> /root/.bashrc
# 3️⃣ Restart the shell or run it manually:
# export CF_API_TOKEN="eyJhbGciOi..."
# ==

# --- CONFIG ---
: "${CF_API_TOKEN:?⚠️  Setează CF_API_TOKEN în mediul sistemului (export CF_API_TOKEN=...)}"
ZONE_ID="121112348111133854111117a1b2221f1"
ROOT_DOMAIN="mydomain.com"
SUBDOMAINS=("mydomain.com" "*" "api.mydomain.com" "etc" "etc")

CF_API="https://api.cloudflare.com/client/v4"

# --- FUNCTION: Get public IP ---
get_public_ip() {
    curl -s https://ipv4.icanhazip.com | tr -d ' \n'
}

# --- FUNCTION: Get record info ---
get_record_info() {
    local ZONE_ID=$1
    local RECORD_NAME=$2
    curl -s -X GET "${CF_API}/zones/${ZONE_ID}/dns_records?type=A&name=${RECORD_NAME}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json"
}

# --- FUNCTION: Create record if missing ---
create_record() {
    local ZONE_ID=$1
    local RECORD_NAME=$2
    local NEW_IP=$3
    echo "🆕 The record does not exist. I create $RECORD_NAME → $NEW_IP"
    curl -s -X POST "${CF_API}/zones/${ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${RECORD_NAME}\",\"content\":\"${NEW_IP}\",\"ttl\":1,\"proxied\":false}" \
        | jq -r '.success'
}

# --- FUNCTION: Update record ---
update_dns_record() {
    local ZONE_ID=$1
    local RECORD_ID=$2
    local RECORD_NAME=$3
    local NEW_IP=$4
    echo "🔁 Updating $RECORD_NAME → $NEW_IP"
    curl -s -X PUT "${CF_API}/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${RECORD_NAME}\",\"content\":\"${NEW_IP}\",\"ttl\":1,\"proxied\":false}" \
        | jq -r '.success'
}

# --- MAIN LOGIC ---
CURRENT_IP=$(get_public_ip)
if [[ -z "$CURRENT_IP" ]]; then
    echo "❌ Could not obtain public IP."
    exit 1
fi

echo "🌍 Current public IP: $CURRENT_IP"
echo "──────────────────────────────"

for SUBDOMAIN in "${SUBDOMAINS[@]}"; do
    if [[ "$SUBDOMAIN" == "*" ]]; then
        RECORD_NAME="*.${ROOT_DOMAIN}"
    elif [[ "$SUBDOMAIN" == "$ROOT_DOMAIN" ]]; then
        RECORD_NAME="$ROOT_DOMAIN"
    else
        RECORD_NAME="$SUBDOMAIN"
    fi

    echo "🔍 CHECK $RECORD_NAME"
    RECORD_INFO=$(get_record_info "$ZONE_ID" "$RECORD_NAME")

    RECORD_ID=$(echo "$RECORD_INFO" | jq -r '.result[0].id // empty')
    RECORD_IP=$(echo "$RECORD_INFO" | jq -r '.result[0].content // empty')

    if [[ -z "$RECORD_ID" ]]; then
        create_record "$ZONE_ID" "$RECORD_NAME" "$CURRENT_IP" >/dev/null
        echo "✅ Record created: $RECORD_NAME → $CURRENT_IP"
        echo "──────────────────────────────"
        continue
    fi

    if [[ "$RECORD_IP" != "$CURRENT_IP" ]]; then
        update_dns_record "$ZONE_ID" "$RECORD_ID" "$RECORD_NAME" "$CURRENT_IP" >/dev/null
        echo "✅ Record updated: $RECORD_NAME ($RECORD_IP → $CURRENT_IP)"
    else
        echo "ℹ️  $RECORD_NAME already has the IP $CURRENT_IP — nothing to change."
    fi
    echo "──────────────────────────────"
done

echo "🏁 All records were processed securely."
