#!/usr/bin/env bash
set -euo pipefail

target_dir="${1:-$(pwd)/files/grafana/dashboards}"

test -d "$target_dir" || {
  echo "$target_dir does not exist"
  exit 1
}

download_dashboard() {
  local id=$1
  local version=$2
  local dest=$3
  local url="https://grafana.com/api/dashboards/${id}/revisions/${version}/download"
  echo "$dest"
  if [ ! -f "$dest" ]; then
    echo "Downloading $url -> $dest"
    curl -SsL -o "$dest" "$url"
    # Normalize datasource names and default time range to 1h
    sed -i 's/${DS_PROMETHEUS}/DS_PROMETHEUS/g' "$dest"
    sed -i 's/${DS}/DS_PROMETHEUS/g' "$dest"
    sed -i 's/${DS_NATS-PROMETHEUS}/DS_PROMETHEUS/g' "$dest"
    sed -E -i 's/now-[0-9]+[mh]/now-1h/g' "$dest"
    sed -i 's/now\/d/now-1h/g' "$dest"
  else
    echo "File $dest already exists, skipping."
  fi
}

mkdir -p "$target_dir/imported/nats" \
         "$target_dir/imported/rocketchat" \
         "$target_dir/imported/mongodb" \
         "$target_dir/imported/prometheus"

# Prometheus overview
download_dashboard 2 latest "$target_dir/imported/prometheus/prometheus-stats.json"
# Node exporter full
download_dashboard 1860 latest "$target_dir/imported/prometheus/node-exporter-full.json"
# Traefik 2 dashboard (community)
download_dashboard 12250 latest "$target_dir/imported/prometheus/traefik-v2.json"
# Rocket.Chat (community)
download_dashboard 23428 latest "$target_dir/imported/rocketchat/rocketchat-metrics.json"
# NATS server
download_dashboard 2279 latest "$target_dir/imported/nats/nats-server.json"
# MongoDB exporter
download_dashboard 23712 latest "$target_dir/imported/mongodb/mongodb-exporter.json"

echo "Dashboards downloaded/updated under $target_dir/imported"