#!/usr/bin/env bash
set -euxo pipefail

# Clean up any existing setup
ip netns del nginx-ns || true
ip link del veth0 || true
ip link del veth1 || true

# Create namespace
ip netns add nginx-ns

# Create first veth pair for enp7s0
ip link add veth0 type veth peer name veth0-nginx
ip addr add 10.10.0.1/24 dev veth0
ip link set veth0 up
ip link set veth0-nginx netns nginx-ns

# Create second veth pair for enp7s0.18
ip link add veth1 type veth peer name veth1-nginx
ip addr add 10.10.1.1/24 dev veth1
ip link set veth1 up
ip link set veth1-nginx netns nginx-ns

# Configure inside namespace
ip netns exec nginx-ns bash <<'EOF'
set -euo pipefail
ip addr add 10.10.0.2/24 dev veth0-nginx
ip addr add 10.10.1.2/24 dev veth1-nginx
ip link set veth0-nginx up
ip link set veth1-nginx up
ip link set lo up
EOF
