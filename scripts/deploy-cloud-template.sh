#!/bin/bash
# Cloud Deployment Template Script
# Customize this script for your specific cloud provider

set -e

echo "🚀 Rocket.Chat Observability - Cloud Deployment Template"
echo "========================================================"
echo ""
echo "⚠️  IMPORTANT: This is a template script."
echo "   Please customize it for your specific cloud provider before using."
echo ""

# Configuration - EDIT THESE VALUES
CLOUD_PROVIDER="your-cloud-provider"  # e.g., "aws", "azure", "gcp", "digitalocean"
VM_NAME="rocketchat-observability"
VM_SIZE="Standard_B2s"  # Adjust based on your provider
REGION="us-east-1"      # Adjust based on your provider
SSH_KEY_NAME="your-ssh-key"
DOMAIN="your-domain.com"

echo "📋 Current Configuration:"
echo "   Cloud Provider: $CLOUD_PROVIDER"
echo "   VM Name: $VM_NAME"
echo "   VM Size: $VM_SIZE"
echo "   Region: $REGION"
echo "   Domain: $DOMAIN"
echo ""

# Check if configuration has been customized
if [ "$CLOUD_PROVIDER" = "your-cloud-provider" ]; then
    echo "❌ Error: Please customize this script before running."
    echo "   Edit the configuration variables at the top of this script."
    exit 1
fi

echo "🔍 Checking prerequisites..."

# Check if cloud CLI is installed
check_cloud_cli() {
    case $CLOUD_PROVIDER in
        "aws")
            if ! command -v aws &> /dev/null; then
                echo "❌ AWS CLI not found. Install with: pip install awscli"
                exit 1
            fi
            ;;
        "azure")
            if ! command -v az &> /dev/null; then
                echo "❌ Azure CLI not found. Install with: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
                exit 1
            fi
            ;;
        "gcp")
            if ! command -v gcloud &> /dev/null; then
                echo "❌ Google Cloud CLI not found. Install from: https://cloud.google.com/sdk/docs/install"
                exit 1
            fi
            ;;
        "digitalocean")
            if ! command -v doctl &> /dev/null; then
                echo "❌ DigitalOcean CLI not found. Install with: snap install doctl"
                exit 1
            fi
            ;;
        *)
            echo "❌ Unsupported cloud provider: $CLOUD_PROVIDER"
            exit 1
            ;;
    esac
}

check_cloud_cli
echo "✅ Cloud CLI found"

# Create VM based on provider
create_vm() {
    echo "🖥️  Creating VM on $CLOUD_PROVIDER..."
    
    case $CLOUD_PROVIDER in
        "aws")
            # AWS EC2 deployment
            echo "   Creating AWS EC2 instance..."
            # Add your AWS-specific commands here
            # Example:
            # aws ec2 run-instances \
            #     --image-id ami-0c02fb55956c7d316 \
            #     --count 1 \
            #     --instance-type t3.small \
            #     --key-name $SSH_KEY_NAME \
            #     --security-group-ids sg-xxxxxxxxx \
            #     --subnet-id subnet-xxxxxxxxx \
            #     --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value='$VM_NAME'}]'
            echo "   ⚠️  AWS deployment commands need to be customized"
            ;;
            
        "azure")
            # Azure VM deployment
            echo "   Creating Azure VM..."
            # Add your Azure-specific commands here
            # Example:
            # az vm create \
            #     --resource-group myResourceGroup \
            #     --name $VM_NAME \
            #     --image Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest \
            #     --size $VM_SIZE \
            #     --admin-username ubuntu \
            #     --generate-ssh-keys
            echo "   ⚠️  Azure deployment commands need to be customized"
            ;;
            
        "gcp")
            # Google Cloud deployment
            echo "   Creating Google Cloud VM..."
            # Add your GCP-specific commands here
            # Example:
            # gcloud compute instances create $VM_NAME \
            #     --zone=$REGION \
            #     --machine-type=e2-small \
            #     --image-family=ubuntu-2204-lts \
            #     --image-project=ubuntu-os-cloud \
            #     --tags=http-server,https-server
            echo "   ⚠️  GCP deployment commands need to be customized"
            ;;
            
        "digitalocean")
            # DigitalOcean droplet deployment
            echo "   Creating DigitalOcean droplet..."
            # Add your DigitalOcean-specific commands here
            # Example:
            # doctl compute droplet create $VM_NAME \
            #     --size s-1vcpu-1gb \
            #     --image ubuntu-22-04-x64 \
            #     --region $REGION \
            #     --ssh-keys $SSH_KEY_NAME
            echo "   ⚠️  DigitalOcean deployment commands need to be customized"
            ;;
    esac
}

# Deploy the stack to the VM
deploy_stack() {
    echo "🚀 Deploying Rocket.Chat stack..."
    echo "   This will SSH to the VM and deploy the stack"
    
    # Get VM IP (customize based on your provider)
    # VM_IP=$(get_vm_ip)
    
    echo "   ⚠️  Deployment commands need to be customized"
    echo "   Example deployment steps:"
    echo "   1. SSH to VM: ssh ubuntu@$VM_IP"
    echo "   2. Install Docker: curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
    echo "   3. Clone repo: git clone <your-repo-url>"
    echo "   4. Configure: cp env.example .env && nano .env"
    echo "   5. Deploy: make prod-up"
}

# Main execution
echo "📝 This is a template script that needs customization."
echo ""
echo "🔧 To use this script:"
echo "   1. Edit the configuration variables at the top"
echo "   2. Uncomment and customize the deployment commands"
echo "   3. Add your cloud provider-specific commands"
echo "   4. Test in a safe environment first"
echo ""
echo "📚 See docs/DEPLOYMENT_GUIDE.md for detailed instructions"
echo ""

# Uncomment the following lines after customization:
# create_vm
# deploy_stack

echo "✅ Template script completed (no actual deployment performed)"
