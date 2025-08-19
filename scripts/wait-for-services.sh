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
    if check_service "Traefik" "http://localhost:8080/ping" 200; then
        break
    fi
    if [ $i -eq $((TIMEOUT/INTERVAL)) ]; then
        echo "❌ Traefik failed to start within ${TIMEOUT}s"
        exit 1
    fi
    sleep $INTERVAL
done

# Wait for Rocket.Chat
echo "⏳ Waiting for Rocket.Chat..."
for i in $(seq 1 $((TIMEOUT/INTERVAL))); do
    if check_service "Rocket.Chat" "http://localhost:3000/api/info" 200; then
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
    if check_service "Grafana" "http://localhost:5050/api/health" 200; then
        break
    fi
    if [ $i -eq $((TIMEOUT/INTERVAL)) ]; then
        echo "❌ Grafana failed to start within ${TIMEOUT}s"
        exit 1
    fi
    sleep $INTERVAL
done

echo "🎉 All services are healthy!"
