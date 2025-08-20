#!/bin/bash

# Wait for services to be healthy before declaring success
# Usage: ./wait-for-services.sh [timeout_seconds]
#
# 💡 TIP: This script checks health of all services
#    If you get 404 errors after deployment, check your DOMAIN setting in .env
#    For remote access: DOMAIN should be your server IP or domain name

TIMEOUT=${1:-600}  # Default 10 minutes for slower environments
INTERVAL=10

# Color codes for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}${BOLD}🔄 Waiting for services to become healthy${NC} ${YELLOW}(timeout: ${TIMEOUT}s)${NC}"
echo -e "${BLUE}╭─────────────────────────────────────────────────────╮${NC}"
echo -e "${BLUE}│  ${BOLD}Please wait while we verify all services...${NC}${BLUE}        │${NC}"
echo -e "${BLUE}╰─────────────────────────────────────────────────────╯${NC}"
echo ""

check_service() {
    local service=$1
    local url=$2
    local expected_code=${3:-200}
    
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "^${expected_code}"; then
        echo "✅ $service is healthy"
        return 0
    else
        return 1
    fi
}

# Wait for MongoDB and replica set
echo -e "${YELLOW}⏳ [1/4] Checking MongoDB and replica set...${NC}"
for i in $(seq 1 $((TIMEOUT/INTERVAL))); do
    if docker exec rocketchat-observability-mongo-1 mongosh --eval "
        try { 
            db.runCommand('ping'); 
            const status = rs.status(); 
            if (status.ok === 1 && status.myState === 1) { 
                print('MongoDB and replica set healthy'); 
            } else { 
                quit(1); 
            } 
        } catch(e) { 
            quit(1); 
        }
    " >/dev/null 2>&1; then
        echo -e "    ${GREEN}✅ MongoDB is ready${NC}"
        break
    fi
    if [ $i -eq $((TIMEOUT/INTERVAL)) ]; then
        echo -e "    ${RED}❌ MongoDB failed to start within ${TIMEOUT}s${NC}"
        echo -e "    ${YELLOW}🔍 Debug info:${NC}"
        docker exec rocketchat-observability-mongo-1 mongosh --eval "try { rs.status(); } catch(e) { print('Replica set not initialized'); }" 2>/dev/null || echo "MongoDB not accessible"
        exit 1
    fi
    sleep $INTERVAL
done

# Wait for Traefik
echo -e "${YELLOW}⏳ [2/4] Checking Traefik reverse proxy...${NC}"
for i in $(seq 1 $((TIMEOUT/INTERVAL))); do
    # Check if Traefik container is running and healthy
    if docker ps --filter "name=rocketchat-observability-traefik-1" --filter "status=running" --format "{{.Names}}" | grep -q "rocketchat-observability-traefik-1"; then
        # Try to get the actual dashboard port
        TRAEFIK_PORT=$(docker port rocketchat-observability-traefik-1 8080 2>/dev/null | cut -d: -f2)
        if [ -n "$TRAEFIK_PORT" ]; then
            echo -e "    ${BLUE}🔍 Traefik dashboard port detected: $TRAEFIK_PORT${NC}"
            if check_service "Traefik" "http://localhost:$TRAEFIK_PORT/dashboard/" 200; then
                echo -e "    ${GREEN}✅ Traefik is healthy (dashboard: http://localhost:$TRAEFIK_PORT/dashboard/)${NC}"
                break
            elif [ $i -eq 1 ]; then
                echo -e "    ${YELLOW}⏳ Dashboard found but not responding yet, waiting...${NC}"
            fi
        else
            echo -e "    ${YELLOW}⏳ No dashboard port exposed (API might be disabled), checking container...${NC}"
            # No dashboard port (API disabled) - just check container is running for a bit
            if [ $i -gt 10 ]; then
                echo -e "    ${GREEN}✅ Traefik container is running (dashboard disabled)${NC}"
                break
            fi
        fi
    else
        echo -e "    ${YELLOW}⏳ Traefik container not running yet...${NC}"
    fi
    if [ $i -eq $((TIMEOUT/INTERVAL)) ]; then
        echo -e "    ${RED}❌ Traefik failed to start within ${TIMEOUT}s${NC}"
        echo -e "    ${YELLOW}🔍 Debug info:${NC}"
        echo "       Container status: $(docker ps --filter 'name=rocketchat-observability-traefik-1' --format '{{.Status}}')"
        echo "       Last logs:"
        docker logs rocketchat-observability-traefik-1 2>&1 | tail -5
        exit 1
    fi
    sleep $INTERVAL
done

# Wait for Rocket.Chat
echo -e "${YELLOW}⏳ [3/4] Checking Rocket.Chat application...${NC}"
for i in $(seq 1 $((TIMEOUT/INTERVAL))); do
    # Try to get the actual Rocket.Chat port (default 3000)
    RC_PORT=$(docker port rocketchat-observability-rocketchat-1 3000 2>/dev/null | cut -d: -f2)
    if [ -n "$RC_PORT" ] && check_service "Rocket.Chat" "http://localhost:$RC_PORT/api/info" 200; then
        echo -e "    ${GREEN}✅ Rocket.Chat is healthy${NC}"
        break
    elif check_service "Rocket.Chat" "http://localhost:3000/api/info" 200; then
        echo -e "    ${GREEN}✅ Rocket.Chat is healthy${NC}"  
        break
    fi
    if [ $i -eq $((TIMEOUT/INTERVAL)) ]; then
        echo -e "    ${RED}❌ Rocket.Chat failed to start within ${TIMEOUT}s${NC}"
        echo -e "    ${YELLOW}💡 TIP: Check if DOMAIN in .env matches your access method${NC}"
        exit 1
    fi
    sleep $INTERVAL
done

# Wait for Grafana
echo -e "${YELLOW}⏳ [4/4] Checking Grafana monitoring dashboard...${NC}"
for i in $(seq 1 $((TIMEOUT/INTERVAL))); do
    # Try to get the actual Grafana port (default 5050)
    GRAFANA_PORT=$(docker port rocketchat-observability-grafana-1 3000 2>/dev/null | cut -d: -f2)
    if [ -n "$GRAFANA_PORT" ] && check_service "Grafana" "http://localhost:$GRAFANA_PORT/api/health" 200; then
        echo -e "    ${GREEN}✅ Grafana is healthy${NC}"
        break
    elif check_service "Grafana" "http://localhost:5050/api/health" 200; then
        echo -e "    ${GREEN}✅ Grafana is healthy${NC}"
        break
    fi
    if [ $i -eq $((TIMEOUT/INTERVAL)) ]; then
        echo -e "    ${RED}❌ Grafana failed to start within ${TIMEOUT}s${NC}"
        echo -e "    ${YELLOW}💡 TIP: Try accessing http://DOMAIN/grafana/ (note the trailing slash)${NC}"
        exit 1
    fi
    sleep $INTERVAL
done

echo ""
echo -e "${GREEN}${BOLD}🎉 All services are healthy!${NC}"
echo -e "${BLUE}╭─────────────────────────────────────────────────────╮${NC}"
echo -e "${BLUE}│  ${BOLD}Deployment completed successfully! 🚀${NC}${BLUE}              │${NC}"
echo -e "${BLUE}╰─────────────────────────────────────────────────────╯${NC}"
