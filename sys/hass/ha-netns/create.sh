#!/usr/bin/env bash
set -euxo pipefail

# === CONFIGURATION ===
NS_NAME="ha"

# Interface names
IPVLAN_IF="ha-ipvlan"
PHYS_IF="enp1s0.18"

# IP addresses (without netmasks)
IOT_IP="172.18.2.10"
IOT_MASK="20"
IOT_GW="172.18.0.1"

# Veth pair for port forwards
VETH_HOST="ha-veth-host"
VETH_NS="ha-veth-ns"
VETH_HOST_IP="192.168.1.1"
VETH_NS_IP="192.168.1.2"
VETH_MASK="32"

# === TEARDOWN (idempotent) ===

# Remove route if it exists
ip route del "$VETH_NS_IP" dev "$VETH_HOST" 2>/dev/null || true
ip netns del "$NS_NAME" 2>/dev/null || true
ip link del "$VETH_HOST" 2>/dev/null || true
ip link del "$IPVLAN_IF" 2>/dev/null || true

# Create netns
ip netns add "$NS_NAME"

# Create host communication veth pair
ip link add "$VETH_HOST" type veth peer name "$VETH_NS"
ip link set "$VETH_NS" netns "$NS_NAME"
ip addr add "$VETH_HOST_IP/$VETH_MASK" dev "$VETH_HOST"
ip link set "$VETH_HOST" up
ip route add "$VETH_NS_IP" dev "$VETH_HOST"

# Create ipvlan, move to netns
ip link add "$IPVLAN_IF" link "$PHYS_IF" type ipvlan mode l2
ip link set "$IPVLAN_IF" netns "$NS_NAME"

# Configure netns
ip netns exec "$NS_NAME" bash <<EOF
set -euxo pipefail

# Enable loopback
ip link set lo up

# Configure veth-ns
ip addr add '$VETH_NS_IP/$VETH_MASK' dev '$VETH_NS'
ip link set '$VETH_NS' up
ip route add '$VETH_HOST_IP' dev '$VETH_NS'

# Configure ha-ipvlan
ip addr add '$IOT_IP/$IOT_MASK' dev '$IPVLAN_IF'
ip link set '$IPVLAN_IF' up
ip route add default via '$IOT_GW' dev '$IPVLAN_IF'
EOF
