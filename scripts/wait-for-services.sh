#!/bin/bash

# Wait for services to be healthy before declaring success
# Usage: ./wait-for-services.sh [timeout_seconds]

TIMEOUT=${1:-300}  # Default 5 minutes
INTERVAL=5

echo "🔄 Waiting for services to become healthy (timeout: ${TIMEOUT}s)..."

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

# Wait for MongoDB
echo "⏳ Waiting for MongoDB..."
for i in $(seq 1 $((TIMEOUT/INTERVAL))); do
    if docker exec rocketchat-observability-mongo-1 mongosh --eval "db.runCommand('ping')" >/dev/null 2>&1; then
        echo "✅ MongoDB is ready"
        break
    fi
    if [ $i -eq $((TIMEOUT/INTERVAL)) ]; then
        echo "❌ MongoDB failed to start within ${TIMEOUT}s"
        exit 1
    fi
    sleep $INTERVAL
done

# Wait for Traefik
echo "⏳ Waiting for Traefik..."
for i in $(seq 1 $((TIMEOUT/INTERVAL))); do
    # Check if Traefik container is running and healthy
    if docker ps --filter "name=rocketchat-observability-traefik-1" --filter "status=running" --format "{{.Names}}" | grep -q "rocketchat-observability-traefik-1"; then
        # Try to get the actual dashboard port
        TRAEFIK_PORT=$(docker port rocketchat-observability-traefik-1 8080 2>/dev/null | cut -d: -f2)
        if [ -n "$TRAEFIK_PORT" ]; then
            echo "🔍 Traefik dashboard port detected: $TRAEFIK_PORT"
            if check_service "Traefik" "http://localhost:$TRAEFIK_PORT/" 308; then
                echo "✅ Traefik is healthy (dashboard: http://localhost:$TRAEFIK_PORT/dashboard/)"
                break
            elif [ $i -eq 1 ]; then
                echo "⏳ Dashboard found but not responding yet, waiting..."
            fi
        else
            echo "⏳ No dashboard port exposed (API might be disabled), checking container..."
            # No dashboard port (API disabled) - just check container is running for a bit
            if [ $i -gt 10 ]; then
                echo "✅ Traefik container is running (dashboard disabled)"
                break
            fi
        fi
    else
        echo "⏳ Traefik container not running yet..."
    fi
    if [ $i -eq $((TIMEOUT/INTERVAL)) ]; then
        echo "❌ Traefik failed to start within ${TIMEOUT}s"
        echo "🔍 Debug info:"
        echo "   Container status: $(docker ps --filter 'name=rocketchat-observability-traefik-1' --format '{{.Status}}')"
        echo "   Last logs:"
        docker logs rocketchat-observability-traefik-1 2>&1 | tail -5
        exit 1
    fi
    sleep $INTERVAL
done

# Wait for Rocket.Chat
echo "⏳ Waiting for Rocket.Chat..."
for i in $(seq 1 $((TIMEOUT/INTERVAL))); do
    # Try to get the actual Rocket.Chat port (default 3000)
    RC_PORT=$(docker port rocketchat-observability-rocketchat-1 3000 2>/dev/null | cut -d: -f2)
    if [ -n "$RC_PORT" ] && check_service "Rocket.Chat" "http://localhost:$RC_PORT/api/info" 200; then
        echo "✅ Rocket.Chat is healthy"
        break
    elif check_service "Rocket.Chat" "http://localhost:3000/api/info" 200; then
        echo "✅ Rocket.Chat is healthy"  
        break
    fi
    if [ $i -eq $((TIMEOUT/INTERVAL)) ]; then
        echo "❌ Rocket.Chat failed to start within ${TIMEOUT}s"
        exit 1
    fi
    sleep $INTERVAL
done

# Wait for Grafana
echo "⏳ Waiting for Grafana..."
for i in $(seq 1 $((TIMEOUT/INTERVAL))); do
    # Try to get the actual Grafana port (default 5050)
    GRAFANA_PORT=$(docker port rocketchat-observability-grafana-1 3000 2>/dev/null | cut -d: -f2)
    if [ -n "$GRAFANA_PORT" ] && check_service "Grafana" "http://localhost:$GRAFANA_PORT/api/health" 200; then
        echo "✅ Grafana is healthy"
        break
    elif check_service "Grafana" "http://localhost:5050/api/health" 200; then
        echo "✅ Grafana is healthy"
        break
    fi
    if [ $i -eq $((TIMEOUT/INTERVAL)) ]; then
        echo "❌ Grafana failed to start within ${TIMEOUT}s"
        exit 1
    fi
    sleep $INTERVAL
done

echo "🎉 All services are healthy!"
