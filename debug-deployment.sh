#!/bin/bash
# Deployment Debugging Script for rocketchat-observability

echo "=== DEPLOYMENT DEBUGGING SCRIPT ==="
echo "Run this after starting your stack to diagnose issues"
echo ""

echo "1. CONTAINER STATUS CHECK:"
echo "=========================="
make ps
echo ""

echo "2. CONTAINER LOGS (last 20 lines each):"
echo "======================================="
echo "--- Rocket.Chat logs ---"
docker logs --tail 20 $(docker ps --filter "name=rocketchat" --format "{{.Names}}" | head -1) 2>/dev/null || echo "No rocketchat container found"
echo ""

echo "--- Grafana logs ---"
docker logs --tail 20 $(docker ps --filter "name=grafana" --format "{{.Names}}" | head -1) 2>/dev/null || echo "No grafana container found"
echo ""

echo "--- NATS Exporter logs ---"
docker logs --tail 20 $(docker ps --filter "name=nats-exporter" --format "{{.Names}}" | head -1) 2>/dev/null || echo "No nats-exporter container found"
echo ""

echo "--- Traefik logs ---"
docker logs --tail 20 $(docker ps --filter "name=traefik" --format "{{.Names}}" | head -1) 2>/dev/null || echo "No traefik container found"
echo ""

echo "3. VOLUME MOUNT CHECK:"
echo "======================"
echo "Checking if volumes exist and have correct permissions..."
docker volume ls | grep -E "(grafana|prometheus|mongo)"
echo ""

echo "4. NETWORK CONNECTIVITY:"
echo "========================"
echo "Checking if containers can reach each other..."
MONGO_CONTAINER=$(docker ps --filter "name=mongo" --format "{{.Names}}" | head -1)
NATS_CONTAINER=$(docker ps --filter "name=nats-[^e]" --format "{{.Names}}" | head -1)

if [[ -n "$MONGO_CONTAINER" ]]; then
    echo "MongoDB container: $MONGO_CONTAINER"
    docker exec "$MONGO_CONTAINER" ping -c 1 traefik 2>/dev/null && echo "✅ Mongo can reach Traefik" || echo "❌ Mongo cannot reach Traefik"
else
    echo "❌ No MongoDB container found"
fi

if [[ -n "$NATS_CONTAINER" ]]; then
    echo "NATS container: $NATS_CONTAINER"  
    docker exec "$NATS_CONTAINER" nc -z traefik 80 2>/dev/null && echo "✅ NATS can reach Traefik" || echo "❌ NATS cannot reach Traefik"
else
    echo "❌ No NATS container found"
fi

echo ""
echo "5. URL DISCOVERY (testing the new fix):"
echo "======================================="
make url

echo ""
echo "=== DEBUGGING COMPLETE ==="
echo "Look for error patterns in the logs above"
echo "Common issues:"
echo "• Permission denied = volume mount issues"  
echo "• Connection refused = network/service issues"
echo "• 404 in Traefik = routing configuration"
echo "• Database connection errors = MongoDB issues"
