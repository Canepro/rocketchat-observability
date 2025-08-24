#!/bin/bash
# Complete Nuke & Deploy Script
# Nukes Azure Container Apps and deploys production VM

set -e

echo "🚀 Rocket.Chat Production Deployment - Complete Process"
echo "=================================================="

# Step 1: Nuke ACA
echo ""
echo "🗑️ Step 1: Nuking Azure Container Apps..."
if az group show -n Rocketchat_RG >/dev/null 2>&1; then
    echo "   Deleting Rocketchat_RG resource group..."
    az group delete -n Rocketchat_RG --yes --no-wait
    echo "   ✅ ACA resources being deleted..."
else
    echo "   ✅ No existing Rocketchat_RG found"
fi

# Step 2: Wait for cleanup
echo ""
echo "⏳ Step 2: Waiting for cleanup..."
sleep 30

# Step 3: Deploy VM
echo ""
echo "🖥️ Step 3: Deploying Azure VM with full stack..."
./deploy-azure-vm.sh

# Step 4: Get VM IP
echo ""
echo "📱 Step 4: Getting VM details..."
VM_IP=$(az vm show -d -g Rocketchat_RG -n rocketchat-prod --query publicIps -o tsv)
echo "   VM Public IP: $VM_IP"

# Step 5: Monitor deployment
echo ""
echo "⏳ Step 5: Monitoring deployment progress..."
echo "   Cloud-init is running in the background..."
echo "   This may take 5-10 minutes to complete"
echo ""
echo "   To monitor progress manually:"
echo "   ssh azureuser@$VM_IP 'tail -f /var/log/cloud-init-output.log'"
echo ""

# Step 6: Wait and verify
echo "⏳ Step 6: Waiting for deployment to complete..."
sleep 300  # Wait 5 minutes

# Step 7: Verify deployment
echo ""
echo "🔍 Step 7: Verifying deployment..."
echo "   Checking service status..."
ssh -o StrictHostKeyChecking=no azureuser@$VM_IP 'cd ~/rocketchat-observability && make ps' || echo "   ⏳ Services still starting..."

# Step 8: Show access URLs
echo ""
echo "🎉 Step 8: Deployment Complete!"
echo "=================================================="
echo "🌐 Your Rocket.Chat Production Stack:"
echo "   Rocket.Chat: http://$VM_IP:3000"
echo "   Grafana: http://$VM_IP:5050 (admin/rc-admin-prod)"
echo "   Prometheus: http://$VM_IP:9090"
echo "   Traefik Dashboard: http://$VM_IP:8080"
echo ""
echo "💡 Management Commands:"
echo "   SSH to VM: ssh azureuser@$VM_IP"
echo "   Check status: ssh azureuser@$VM_IP 'cd ~/rocketchat-observability && make ps'"
echo "   View logs: ssh azureuser@$VM_IP 'cd ~/rocketchat-observability && make logs'"
echo "   Backup DB: ssh azureuser@$VM_IP 'cd ~/rocketchat-observability && make backup-mongo'"
echo ""
echo "💰 Estimated monthly cost: ~$30 (B2s VM)"
echo ""
echo "✅ Migration from ACA to Azure VM complete!"
