#!/usr/bin/env bash
# Restore all Kubernetes workloads after EC2 stop/start
# Usage: bash scripts/restore-k8s.sh

set -euo pipefail

ELASTIC_IP="3.74.21.213"
ECR_REGISTRY="658424926455.dkr.ecr.eu-central-1.amazonaws.com"
AWS_REGION="eu-central-1"
AWS_PROFILE="${AWS_PROFILE:-terraform-admin}"
KUBECONFIG_PATH="$HOME/.kube/aws-platform-demo.yaml"

export KUBECONFIG="$KUBECONFIG_PATH"

echo "══════════════════════════════════════════════"
echo "  AWS Platform Demo — K8s Restore"
echo "══════════════════════════════════════════════"

# ── 1. Update kubeconfig ─────────────────────────
echo "⏳ Step 1: Updating kubeconfig..."
ssh-keygen -f "$HOME/.ssh/known_hosts" -R "$ELASTIC_IP" 2>/dev/null || true
ssh -i "$HOME/.ssh/aws-platform-demo" \
  -o StrictHostKeyChecking=no \
  -o ConnectTimeout=30 \
  "ubuntu@$ELASTIC_IP" \
  'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed "s/127.0.0.1/$ELASTIC_IP/" \
  > "$KUBECONFIG_PATH"
echo "✅ kubeconfig updated"

# ── 2. Wait for k3s ─────────────────────────────
echo "⏳ Step 2: Waiting for k3s..."
until kubectl get nodes | grep -q Ready; do
  sleep 5
done
echo "✅ k3s ready"
kubectl get nodes

# ── 3. ECR token ────────────────────────────────
echo "⏳ Step 3: ECR authentication..."
ECR_TOKEN=$(aws ecr get-login-password \
  --region "$AWS_REGION" \
  --profile "$AWS_PROFILE")

kubectl create secret docker-registry ecr-secret \
  --docker-server="$ECR_REGISTRY" \
  --docker-username=AWS \
  --docker-password="$ECR_TOKEN" \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✅ ECR secret updated"

# ── 4. Fluent Bit ────────────────────────────────
echo "⏳ Step 4: Fluent Bit..."
kubectl create namespace logging 2>/dev/null || true
if helm status fluent-bit -n logging &>/dev/null; then
  echo "  already installed, skipping"
else
  helm install fluent-bit fluent/fluent-bit \
    --namespace logging \
    -f "$(dirname "$0")/../k8s/fluent-bit-values.yaml"
fi
echo "✅ Fluent Bit ready"

# ── 5. External Secrets Operator ────────────────
echo "⏳ Step 5: External Secrets Operator..."
kubectl create namespace external-secrets 2>/dev/null || true
if helm status external-secrets -n external-secrets &>/dev/null; then
  echo "  already installed, skipping"
else
  helm install external-secrets external-secrets/external-secrets \
    --namespace external-secrets \
    --set resources.requests.memory=64Mi \
    --set resources.limits.memory=128Mi \
    --set webhook.resources.requests.memory=32Mi \
    --set webhook.resources.limits.memory=64Mi \
    --set certController.resources.requests.memory=32Mi \
    --set certController.resources.limits.memory=64Mi \
    --wait --timeout 5m
fi

kubectl apply -f "$(dirname "$0")/../k8s/cluster-secret-store.yaml"
kubectl apply -f "$(dirname "$0")/../k8s/external-secret-demo-app.yaml"
echo "✅ ESO ready"

# ── 6. Demo app ──────────────────────────────────
echo "⏳ Step 6: Demo app..."
kubectl apply -f - << 'MANIFEST'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
    spec:
      imagePullSecrets:
        - name: ecr-secret
      containers:
        - name: demo-app
          image: 658424926455.dkr.ecr.eu-central-1.amazonaws.com/aws-platform-demo:v1.0.0
          ports:
            - containerPort: 8080
          env:
            - name: AWS_REGION
              value: eu-central-1
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  namespace: default
spec:
  type: NodePort
  selector:
    app: demo-app
  ports:
    - port: 8080
      targetPort: 8080
      nodePort: 30080
MANIFEST
echo "✅ Demo app deployed"

# ── 7. Atlantis ──────────────────────────────────
echo "⏳ Step 7: Atlantis..."
kubectl create namespace atlantis 2>/dev/null || true

# Check if secrets exist
if ! kubectl get secret atlantis-secrets -n atlantis &>/dev/null; then
  echo "⚠️  atlantis-secrets not found — create manually:"
  echo "  kubectl create secret generic atlantis-secrets \\"
  echo "    --namespace atlantis \\"
  echo "    --from-literal=github-token=<token> \\"
  echo "    --from-literal=webhook-secret=<secret>"
else
  kubectl apply -f "$(dirname "$0")/../k8s/atlantis.yaml"
  echo "✅ Atlantis deployed"
fi

# ── 8. Final status ──────────────────────────────
echo ""
echo "⏳ Waiting for pods to be ready..."
sleep 30

echo ""
echo "══════════════════════════════════════════════"
echo "  Final Status"
echo "══════════════════════════════════════════════"
kubectl get pods -A

echo ""
echo "══════════════════════════════════════════════"
echo "  Endpoints"
echo "══════════════════════════════════════════════"
echo "  demo-app:  http://$ELASTIC_IP:30080/health"
echo "  atlantis:  http://$ELASTIC_IP:30141/healthz"
curl -s "http://$ELASTIC_IP:30080/health" 2>/dev/null && echo "" || echo "  demo-app not ready yet"
curl -s "http://$ELASTIC_IP:30141/healthz" 2>/dev/null && echo "" || echo "  atlantis not ready yet"
