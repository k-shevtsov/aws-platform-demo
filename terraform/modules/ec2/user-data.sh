#!/bin/bash
set -euo pipefail

# IMDSv2 token
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Wait for Elastic IP association (may take a few seconds)
sleep 10
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4)

# Write k3s config with TLS SAN before installation
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/config.yaml << K3SCONFIG
tls-san:
  - "${elastic_ip}"
  - "$PUBLIC_IP"
write-kubeconfig-mode: "644"
disable:
  - traefik
K3SCONFIG

# Install k3s
curl -sfL https://get.k3s.io | sh -s -

# Wait for k3s to be ready
sleep 30
until kubectl get nodes | grep -q Ready; do
  sleep 5
done

echo "user-data complete: $(date)" > /tmp/user-data-complete
