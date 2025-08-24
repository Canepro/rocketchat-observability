#!/bin/bash
# Azure VM Deployment Script for Rocket.Chat Production Stack
# Budget-friendly, always-on setup

set -e

echo "🚀 Deploying Rocket.Chat Production Stack on Azure VM..."

# Resource group
echo "📦 Creating resource group..."
az group create --name Rocketchat_RG --location uksouth

# Create VM with cloud-init
echo "🖥️ Creating VM with auto-setup..."
az vm create \
  --resource-group Rocketchat_RG \
  --name rocketchat-prod \
  --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest \
  --size Standard_B2s \
  --admin-username azureuser \
  --generate-ssh-keys \
  --public-ip-sku Standard \
  --nsg-rule None \
  --custom-data cloud-init.yaml

# Open required ports with different priorities
echo "🔓 Opening ports..."
az vm open-port --resource-group Rocketchat_RG --name rocketchat-prod --port 22 --priority 1000
az vm open-port --resource-group Rocketchat_RG --name rocketchat-prod --port 80 --priority 1001
az vm open-port --resource-group Rocketchat_RG --name rocketchat-prod --port 443 --priority 1002
az vm open-port --resource-group Rocketchat_RG --name rocketchat-prod --port 3000 --priority 1003
az vm open-port --resource-group Rocketchat_RG --name rocketchat-prod --port 5050 --priority 1004
az vm open-port --resource-group Rocketchat_RG --name rocketchat-prod --port 9090 --priority 1005
az vm open-port --resource-group Rocketchat_RG --name rocketchat-prod --port 8080 --priority 1006

# Get IP
VM_IP=$(az vm show -d -g Rocketchat_RG -n rocketchat-prod --query publicIps -o tsv)

echo ""
echo "🎉 VM Created Successfully!"
echo "📱 VM Public IP: $VM_IP"
echo ""
echo "⏳ Waiting for cloud-init to complete (this may take 5-10 minutes)..."
echo "You can monitor progress with: ssh azureuser@$VM_IP 'tail -f /var/log/cloud-init-output.log'"
echo ""
echo "🌐 Once setup completes, access your stack at:"
echo "   Rocket.Chat: http://$VM_IP:3000"
echo "   Grafana: http://$VM_IP:5050 (admin/rc-admin-prod)"
echo "   Prometheus: http://$VM_IP:9090"
echo "   Traefik Dashboard: http://$VM_IP:8080"
echo ""
echo "💡 To check deployment status:"
echo "   ssh azureuser@$VM_IP 'cd ~/rocketchat-observability && make ps'"
echo ""
echo "💰 Estimated monthly cost: ~$30 (B2s VM)"
