#!/bin/bash
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
# If the directory `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable --now kubelet
set -euo pipefail

echo "=== Mise à jour du système ==="
apt-get update
apt-get upgrade -y

echo "=== Installation des dépendances ==="
apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    apt-transport-https

echo "=== Installation de Containerd ==="
apt-get install -y containerd

echo "=== Génération de la configuration ==="
mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

echo "=== Configuration SystemdCgroup ==="
sed -i \
    's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml

echo "=== Redémarrage du service ==="
systemctl daemon-reload
systemctl enable containerd
systemctl restart containerd

echo "=== Vérification ==="
systemctl --no-pager --full status containerd

echo
echo "Containerd installé avec succès."
echo "Version :"
containerd --version

echo "=== Configuration Kernel Kubernetes ==="

cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

echo "=== Désactivation du swap ==="
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
systemctl status containerd
ctr version
crictl info
