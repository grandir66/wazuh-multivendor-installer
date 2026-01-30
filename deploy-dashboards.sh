#!/bin/bash
#
# Wazuh Dashboard Import Script
# Automatically imports all dashboards and visualizations
#
# Usage: ./deploy-dashboards.sh [WAZUH_URL]
#

set -e

# Disable bash history expansion to handle passwords with special characters (!, $, etc.)
set +H

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Wazuh Dashboard Import Tool${NC}"
echo -e "${GREEN}  WazuhMikrotik Project${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="${SCRIPT_DIR}/dashboards"

# Check if dashboards directory exists
if [ ! -d "$DASHBOARD_DIR" ]; then
    echo -e "${RED}Error: Dashboard directory not found: $DASHBOARD_DIR${NC}"
    echo -e "${YELLOW}Make sure you're running this script from the repository root${NC}"
    exit 1
fi

# Get Wazuh URL
if [ -n "$1" ]; then
    WAZUH_URL="$1"
else
    echo -e "${BLUE}Enter Wazuh Dashboard URL${NC}"
    echo -e "${YELLOW}Example: https://da-wazuh.domarc.it${NC}"
    read -p "URL: " WAZUH_URL
fi

# Remove trailing slash if present
WAZUH_URL="${WAZUH_URL%/}"

# Validate URL
if [[ ! "$WAZUH_URL" =~ ^https?:// ]]; then
    echo -e "${RED}Error: Invalid URL. Must start with http:// or https://${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}Wazuh URL: ${GREEN}$WAZUH_URL${NC}"
echo ""

# Get credentials
echo -e "${BLUE}Enter Wazuh credentials${NC}"
read -p "Username: " WAZUH_USER

# Read password securely (hidden input)
# Note: Password can contain special characters like !, $, @, etc.
echo -n "Password: "
IFS= read -rs WAZUH_PASS
echo ""
echo ""

# Validate password is not empty
if [ -z "$WAZUH_PASS" ]; then
    echo -e "${RED}Error: Password cannot be empty${NC}"
    exit 1
fi

# Test connection
echo -e "${YELLOW}Testing connection to Wazuh...${NC}"

# Create temporary netrc file for secure credential handling
NETRC_FILE=$(mktemp)
chmod 600 "$NETRC_FILE"
cat > "$NETRC_FILE" << NETRC_EOF
machine $(echo "$WAZUH_URL" | sed -E 's|https?://||' | sed 's|/.*||')
login ${WAZUH_USER}
password ${WAZUH_PASS}
NETRC_EOF

# Cleanup function
cleanup() {
    rm -f "$NETRC_FILE" 2>/dev/null
}
trap cleanup EXIT

HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" \
    --netrc-file "$NETRC_FILE" \
    "${WAZUH_URL}/api/status" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" == "000" ]; then
    echo -e "${RED}Error: Cannot connect to $WAZUH_URL${NC}"
    echo -e "${YELLOW}Check the URL and network connectivity${NC}"
    exit 1
elif [ "$HTTP_CODE" == "401" ]; then
    echo -e "${RED}Error: Authentication failed (401)${NC}"
    echo -e "${YELLOW}Check username and password${NC}"
    exit 1
elif [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "302" ]; then
    echo -e "${YELLOW}Warning: Received HTTP $HTTP_CODE, but continuing...${NC}"
else
    echo -e "${GREEN}✓ Connection successful${NC}"
fi

echo ""

# List available dashboards
echo -e "${BLUE}Available dashboards to import:${NC}"
DASHBOARDS=()
for file in "$DASHBOARD_DIR"/*.ndjson; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        DASHBOARDS+=("$file")
        echo -e "  - ${GREEN}$filename${NC}"
    fi
done

if [ ${#DASHBOARDS[@]} -eq 0 ]; then
    echo -e "${RED}No dashboard files (.ndjson) found in $DASHBOARD_DIR${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Found ${#DASHBOARDS[@]} dashboard file(s) to import${NC}"
echo ""

# Confirm import
read -p "Proceed with import? (y/n): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Import cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Starting Import...${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Import each dashboard
SUCCESS_COUNT=0
FAIL_COUNT=0

for dashboard in "${DASHBOARDS[@]}"; do
    filename=$(basename "$dashboard")
    echo -e "${BLUE}Importing: ${NC}$filename"
    
    # Import via API using netrc for secure credential handling
    RESPONSE=$(curl -k -s -X POST \
        "${WAZUH_URL}/api/saved_objects/_import?overwrite=true" \
        -H "osd-xsrf: true" \
        -H "Content-Type: multipart/form-data" \
        --netrc-file "$NETRC_FILE" \
        -F "file=@${dashboard}" 2>&1)
    
    # Check response
    if echo "$RESPONSE" | grep -q '"success":true'; then
        echo -e "  ${GREEN}✓ Success${NC}"
        ((SUCCESS_COUNT++))
    elif echo "$RESPONSE" | grep -q '"successCount"'; then
        # Extract success count
        IMPORTED=$(echo "$RESPONSE" | grep -o '"successCount":[0-9]*' | grep -o '[0-9]*')
        echo -e "  ${GREEN}✓ Success - Imported $IMPORTED objects${NC}"
        ((SUCCESS_COUNT++))
    elif echo "$RESPONSE" | grep -q 'error'; then
        echo -e "  ${RED}✗ Failed${NC}"
        echo -e "  ${YELLOW}Response: ${RESPONSE:0:200}...${NC}"
        ((FAIL_COUNT++))
    else
        echo -e "  ${YELLOW}⚠ Unknown response${NC}"
        echo -e "  ${YELLOW}Response: ${RESPONSE:0:200}${NC}"
        ((SUCCESS_COUNT++))
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Import Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "  ${GREEN}Successful: $SUCCESS_COUNT${NC}"
echo -e "  ${RED}Failed: $FAIL_COUNT${NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo -e "${GREEN}All dashboards imported successfully!${NC}"
    echo ""
    echo -e "${BLUE}Access your dashboards:${NC}"
    echo -e "  1. Open ${GREEN}$WAZUH_URL${NC}"
    echo -e "  2. Go to ${GREEN}☰ Menu → Dashboard${NC}"
    echo -e "  3. Search for:"
    echo -e "     - ${GREEN}Mikrotik Security Dashboard${NC}"
    echo -e "     - ${GREEN}Log Explorer Dashboard${NC}"
    echo -e "     - ${GREEN}Log Explorer Dashboard v2${NC}"
else
    echo -e "${YELLOW}Some imports failed. Try importing manually via the web interface.${NC}"
    echo -e "${YELLOW}Go to: Management → Saved Objects → Import${NC}"
fi

echo ""
echo -e "${GREEN}Done!${NC}"
