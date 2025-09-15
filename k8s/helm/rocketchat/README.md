# Rocket.Chat Helm Chart

A Helm chart for deploying Rocket.Chat with 2 pods in monolithic mode on Kubernetes.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Nginx Ingress Controller
- External MongoDB instance

## Installing the Chart

### Using the deployment script (recommended)
```bash
cd k8s
./deploy.sh deploy
```

### Using Helm directly
```bash
# Add the chart directory
helm install rocketchat ./k8s/helm/rocketchat

# Or from a packaged chart
helm install rocketchat rocketchat-0.1.0.tgz
```

## Configuration

The following table lists the configurable parameters of the Rocket.Chat chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `image.repository` | Rocket.Chat image repository | `rocketchat/rocket.chat` |
| `image.tag` | Rocket.Chat image tag | `"7.9.3"` |
| `replicaCount` | Number of Rocket.Chat pods | `2` |
| `externalMongodb.url` | External MongoDB connection URL | `mongodb://host.docker.internal:27017/rocketchat` |
| `externalMongodb.oplogUrl` | External MongoDB oplog URL | `mongodb://host.docker.internal:27017/local` |
| `rocketchat.rootUrl` | Rocket.Chat root URL | `http://52.183.221.89` |
| `service.type` | Kubernetes service type | `ClusterIP` |
| `ingress.enabled` | Enable nginx ingress | `true` |
| `ingress.hosts[0].host` | Ingress host | `52.183.221.89` |
| `resources.requests.memory` | Memory request | `1Gi` |
| `resources.requests.cpu` | CPU request | `500m` |
| `resources.limits.memory` | Memory limit | `2Gi` |
| `resources.limits.cpu` | CPU limit | `1000m` |

## Customizing Values

Create a custom values file:

```yaml
# custom-values.yaml
replicaCount: 3

externalMongodb:
  url: "mongodb://your-mongodb-host:27017/rocketchat"
  oplogUrl: "mongodb://your-mongodb-host:27017/local"

rocketchat:
  rootUrl: "https://chat.yourdomain.com"

ingress:
  tls:
    - secretName: rocketchat-tls
      hosts:
        - chat.yourdomain.com
```

Install with custom values:
```bash
helm install rocketchat ./k8s/helm/rocketchat -f custom-values.yaml
```

## Access Rocket.Chat

After deployment, access Rocket.Chat at: `http://52.183.221.89`

Default credentials:
- Username: `admin`
- Password: `changeme123`

## Scaling

Scale the deployment:
```bash
# Using kubectl
kubectl scale deployment rocketchat --replicas=3

# Using Helm
helm upgrade rocketchat ./k8s/helm/rocketchat --set replicaCount=3
```

## Troubleshooting

See `k8s/troubleshooting.md` for detailed troubleshooting information.

## Uninstallation

```bash
# Using the script
cd k8s
./deploy.sh cleanup

# Using Helm
helm uninstall rocketchat
```

## Architecture

This chart deploys:
- Rocket.Chat deployment with configurable replicas
- Nginx ingress with hash-based load balancing
- Service for internal load balancing
- ConfigMap for environment variables
- Pod Disruption Budget for high availability
- ServiceAccount for proper permissions

## Security

The chart includes:
- Non-root user execution (UID 999)
- Read-only root filesystem
- Security contexts
- Pod anti-affinity for high availability
- Resource limits and requests
