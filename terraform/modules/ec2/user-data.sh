#!/bin/bash
set -euo pipefail

# Get public IP
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Install k3s with public IP in TLS SAN
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --disable traefik \
  --tls-san "$PUBLIC_IP"

# Wait for k3s to be ready
sleep 30
until kubectl get nodes | grep -q Ready; do
  sleep 5
done

# Install AWS CLI
snap install aws-cli --classic 2>/dev/null || true

# Tag completion
echo "user-data complete: $(date)" > /tmp/user-data-complete
