# Homelab Container Platform Plan

Declarative container platform with strong isolation, selective exposure, and local PKI.

## Requirements

### Exposure & TLS
- [ ] All LAN-exposed services through TLS-terminating proxy
- [ ] Separate tailnet exposure, same certificates
- [ ] Selective per-service tailnet exposure
- [ ] StepCA for certificate management

### Isolation & Enforcement
- [ ] VLAN segmentation: IoT devices isolated from main network
- [ ] Tailnet container tightly isolated (proxy access only)
- [ ] Internal traffic flows catalogued and enforced via NetworkPolicy
- [ ] User namespace remapping where possible
- [ ] Capability lockdown, readonly root

### Special Requirements
- [ ] hass: L2/mDNS access, exposed to IoT VLAN
- [ ] gitea: SSH (port 22) on separate IP with client allowlisting
- [ ] jellyfin: exposed to IoT VLAN (smart TVs)
- [ ] Declarative everything (git-managed YAML)

## Physical Architecture

Single server, serial bridge for remote zwave radio, VLAN-segmented network.

```
┌─────────────────────────────────────────────────────────────────────┐
│ Main VLAN (trusted - 192.168.1.0/24)                                │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │ Server (single-node k0s)                                      │  │
│  │                                                               │  │
│  │  Ingress:     lan-proxy, tailnet-proxy, tailscale            │  │
│  │  Apps:        gitea, jellyfin, file-server, hass, grafana    │  │
│  │  IoT:         zwave-js, mqtt                                  │  │
│  │  Data:        postgres, stepca                                │  │
│  │                                                               │  │
│  │  hass ────────────────────────────────────────────────────────┼──┤► IoT VLAN
│  │  jellyfin ────────────────────────────────────────────────────┼──┤► IoT VLAN
│  │                                                               │  │
│  │  zwave-js ─── tcp://serial-bridge:3333 ───────────────────────┼──┤
│  │                                                               │  │
│  │  Multus: hass on br0 for mDNS                                 │  │
│  │  NetworkPolicy: full isolation between tiers                  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
└───────────────────────────────────────────────────────────────────┬─┘
                                                                    │
┌───────────────────────────────────────────────────────────────────┴─┐
│ IoT VLAN (untrusted - 192.168.2.0/24)                               │
│                                                                     │
│  IoT devices ──► hass (control, mDNS discovery)                     │
│  Smart TVs ──► jellyfin (streaming)                                 │
│  ESPHome devices, sensors, etc.                                     │
│                                                                     │
│  ┌───────────────────┐                                              │
│  │ Serial Bridge     │                                              │
│  │                   │                                              │
│  │  USB zwave ─────────► tcp:3333 ──► server                       │
│  │                   │                                              │
│  │  Options:         │                                              │
│  │  - ESP32/ESPHome  │                                              │
│  │  - Pi Zero + ser2net                                            │
│  │  - Any ser2net box│                                              │
│  └───────────────────┘                                              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Why Single Server?

| Concern | Mitigation |
|---------|------------|
| Blast radius | NetworkPolicy isolates workloads |
| IoT-facing services | Same kernel, but container isolation sufficient for homelab |
| USB device location | Serial bridge (ESP32, Pi, etc.) |
| mDNS for hass | Multus to br0 |
| Complexity | One cluster, one machine, one config repo |

### Serial Bridge

Zwave radio needs physical placement for coverage. Bridge serial to TCP:

```
USB zwave controller
        │
        ▼
Serial Bridge (ESP32, Pi, etc.)
        │
        │ tcp:3333
        ▼
zwave-js pod (connects to tcp://serial-bridge:3333)
```

Options:
- **ESP32 + ESPHome**: `stream_server` component, ~$5, <1W, no maintenance
- **Pi Zero + ser2net**: More flexible, runs NixOS if you want
- **Any Linux box**: `socat` or `ser2net`

### VLAN Exposure

**Router-level rules (simplest):**
- Firewall allows IoT VLAN → specific main VLAN IPs/ports
- hass/jellyfin have main VLAN IPs only
- Serial bridge on IoT VLAN, server reaches it

### Security Boundaries

```
Strongest ─────────────────────────────────────────────── Weakest

Physical        VM           Container+userns+seccomp     Container
separation                                                (root)
                                     │
                                     └── You are here
                                         (sufficient for homelab)
```

| Layer | Protects against |
|-------|------------------|
| NetworkPolicy | Pod-to-pod lateral movement |
| User namespaces | Container escape → unprivileged user |
| Seccomp | Dangerous syscalls |
| Read-only root | Persistent malware |
| Capability drop | Privileged operations |

Escape requires chaining: exploit app → escape container → bypass NetworkPolicy/kernel. Theoretical for homelab threat model.

## Cluster Architecture (k0s)

### Exposure Model

```
Main VLAN Clients                    Tailnet Clients
     │                                      │
     ▼                                      ▼
lan-proxy (br0 IP)                   tailscale pod
     │                                      │
     │ TLS (stepca certs)                   │ NetworkPolicy: tailnet-proxy only
     ▼                                      ▼
 ┌───────────────────────────────────────────────┐
 │              tailnet-proxy                    │
 │         TLS (same stepca certs)               │
 │    selective exposure via IngressRoute        │
 └───────────────────────────────────────────────┘
                      │
                      ▼
              application services
```

**Two proxies for isolation:**
- lan-proxy: Main VLAN-facing, all services
- tailnet-proxy: tailnet-facing, selected services only
- Tailscale can't reach lan-proxy (NetworkPolicy)

### Gitea: Separate SSH Access

```
┌─ br0 ─────────────────────────────────────────┐
│                                               │
│   gitea-ssh (192.168.1.12)                    │
│       │                                       │
│       │ Multus: dedicated br0 IP              │
│       │ Host nftables: allowlist source IPs   │
│       │                                       │
└───────│───────────────────────────────────────┘
        │
        ▼
   gitea pod (cluster network)
        │
        ├── :22 ← from gitea-ssh IP (allowlisted)
        └── :3000 ← from lan-proxy (web UI)
```

### Services

| Service | Exposure | Notes |
|---------|----------|-------|
| gitea (web) | lan-proxy, tailnet-proxy | Web UI |
| gitea (ssh) | dedicated br0 IP, allowlisted | Git operations |
| jellyfin | lan-proxy, IoT VLAN (router rules) | Streaming |
| file-server | lan-proxy, tailnet-proxy | TBD: copyparty, seafile? |
| hass | lan-proxy, IoT VLAN (router rules), br0 for mDNS | Home automation |
| zwave-js | cluster-internal | Connects to serial bridge |
| mqtt | cluster-internal | Pub/sub |
| stepca | cluster-internal | PKI |
| postgres | cluster-internal | Shared DB |
| grafana | lan-proxy, tailnet-proxy | Monitoring |

## Platform: k0s + Calico

### Why k0s

| | k0s | k3s |
|---|-----|-----|
| Philosophy | Minimal secure base, build up | Batteries included, strip down |
| Airgap | First-class, `k0s airgap` command | Possible but not core focus |
| Control plane | Non-root user by default | Root |
| Config model | Declarative YAML (`k0s.yaml`) | CLI flags |
| Bundled extras | None | Must disable things |

### Stack

```
┌─────────────────────────────────────┐
│ Workload manifests (YAML)          │
│   stored in gitea                  │
│   applied via Flux or kubectl      │
├─────────────────────────────────────┤
│ k0s                                 │
│ + Calico (NetworkPolicy)           │
│ + Multus (br0 access)              │
│ + Traefik (ingress, two instances) │
│ + cert-manager + step-issuer       │
│ + StepCA (in-cluster)              │
├─────────────────────────────────────┤
│ NixOS                               │
│ - br0 bridge                       │
│ - k0s service                      │
│ - host nftables (gitea-ssh)        │
└─────────────────────────────────────┘
```

### CNI: Calico

Native k0s support, enforcement-focused.

```yaml
# k0s.yaml
spec:
  network:
    provider: calico
    calico:
      mode: iptables
```

#### Why Calico over Cilium?

| | Calico | Cilium |
|---|--------|--------|
| **Backend** | iptables | eBPF |
| **k0s support** | Native | Manual |
| **L2 service VIPs** | MetalLB | Built-in |
| **True pod L2 (mDNS)** | Multus | Multus (still needed) |
| **L7 policy** | No | Yes |
| **Observability** | Basic | Hubble |
| **Complexity** | Lower | Higher |

Cilium has better observability (Hubble) and eBPF performance, but:
- Still needs Multus for true L2 (hass mDNS requirement)
- More complex for single-node homelab
- k0s has native Calico support

### Multus: Multi-homed Pods

Meta-plugin that attaches additional network interfaces to pods.

```
┌─────────────────────┐
│        Pod          │
│   ┌───────────┐     │
│   │   eth0    │─────┼────► Cluster network (Calico)
│   └───────────┘     │
│   ┌───────────┐     │
│   │   net1    │─────┼────► LAN bridge (br0) - real L2
│   └───────────┘     │
└─────────────────────┘
```

**How it works:**
1. Kubelet calls Multus (configured as CNI)
2. Multus calls Calico → creates eth0 (cluster network)
3. Multus reads pod annotation for extra networks
4. Multus calls macvlan/bridge plugin → creates net1 on br0

**Use cases:**
- hass: mDNS discovery requires L2 adjacency
- lan-proxy: dedicated IP on br0
- gitea-ssh: separate IP for SSH allowlisting

### Ingress: Two Traefik Instances

Separate proxies for LAN vs tailnet - better isolation.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  lan-proxy (Traefik)              tailnet-proxy (Traefik)       │
│    │                                    │                       │
│    │ br0 IP: 192.168.x.10               │ cluster-only IP       │
│    │ exposes: all services              │ exposes: selected     │
│    │                                    │                       │
│    └──────────────┬─────────────────────┘                       │
│                   │                                             │
│                   ▼                                             │
│            application services                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**lan-proxy:**
- Multus: attached to br0 (192.168.x.10)
- Serves all LAN clients
- TLS via StepCA certs

**tailnet-proxy:**
- Cluster network only
- Only reachable from tailscale pod (NetworkPolicy)
- Selective IngressRoutes (only expose what you choose)
- Same StepCA certs

**Tailscale isolation:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tailscale-isolation
spec:
  podSelector:
    matchLabels:
      app: tailscale
  policyTypes: [Egress, Ingress]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: tailnet-proxy
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16]
  ingress: []
```

### StepCA Integration

Run StepCA in-cluster, cert-manager uses step-issuer.

```yaml
# StepCA deployment (simplified)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: step-ca
  namespace: pki
spec:
  template:
    spec:
      containers:
        - name: step-ca
          image: smallstep/step-ca
          volumeMounts:
            - name: ca-config
              mountPath: /home/step/config
            - name: ca-secrets
              mountPath: /home/step/secrets
---
# step-issuer for cert-manager
apiVersion: certmanager.step.sm/v1beta1
kind: StepClusterIssuer
metadata:
  name: step-issuer
spec:
  url: https://step-ca.pki.svc.cluster.local
  caBundle: <base64 root cert>
  provisioner:
    name: cert-manager
    kid: <provisioner key id>
    passwordRef:
      name: step-provisioner-password
      namespace: pki
      key: password
```

Ingresses request certs via annotation:
```yaml
annotations:
  cert-manager.io/cluster-issuer: step-issuer
```

### Multus: br0 Access

For pods needing LAN (hass, lan-proxy, gitea-ssh):

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: lan-bridge
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "bridge",
      "bridge": "br0",
      "ipam": {
        "type": "static",
        "addresses": [{"address": "192.168.x.50/24"}],
        "gateway": "192.168.x.1"
      }
    }
```

Pod annotation: `k8s.v1.cni.cncf.io/networks: lan-bridge`

### Gitea SSH Isolation

Separate network exposure for SSH with client allowlisting:

```yaml
# Gitea SSH gets its own br0 IP
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: gitea-ssh-lan
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "bridge",
      "bridge": "br0",
      "ipam": {
        "type": "static",
        "addresses": [{"address": "192.168.x.30/24"}]
      }
    }
```

**Host-level nftables** allowlists source IPs for 192.168.x.30:22:

```nix
# NixOS
networking.nftables.tables.gitea-ssh = {
  family = "inet";
  content = ''
    chain input {
      type filter hook input priority 0;

      # Allowlist for gitea SSH
      ip daddr 192.168.x.30 tcp dport 22 ip saddr { 192.168.x.100, 192.168.x.101 } accept
      ip daddr 192.168.x.30 tcp dport 22 drop
    }
  '';
};
```

Gitea web goes through lan-proxy like everything else.

### Traffic Flow Catalog

All flows enforced via NetworkPolicy:

| Source | Destination | Port | Purpose |
|--------|-------------|------|---------|
| lan-proxy | gitea | 3000 | Web UI |
| lan-proxy | jellyfin | 8096 | Web UI |
| lan-proxy | file-server | 8080 | Web UI |
| lan-proxy | hass | 8123 | Web UI |
| lan-proxy | grafana | 3000 | Web UI |
| tailnet-proxy | gitea | 3000 | Remote access |
| tailnet-proxy | jellyfin | 8096 | Remote access |
| tailnet-proxy | file-server | 8080 | Remote access |
| tailnet-proxy | hass | 8123 | Remote access |
| tailscale | tailnet-proxy | 443 | Entry point |
| tailscale | internet | * | Coordination |
| hass | mqtt | 1883 | Pub/sub |
| hass | zwave-js | 3000 | Device API |
| hass | postgres | 5432 | Database (recorder) |
| zwave-js | mqtt | 1883 | Pub/sub |
| zwave-js | serial-bridge | 3333 | TCP serial (external) |
| gitea | postgres | 5432 | Database |
| cert-manager | stepca | 443 | Cert issuance |

All other flows: **denied**.

### Example NetworkPolicy (IoT tier)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: zwave-isolation
spec:
  podSelector:
    matchLabels:
      app: zwave
  policyTypes: [Egress, Ingress]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: mqtt
      ports:
        - port: 1883
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: hass
      ports:
        - port: 3000
```

## NixOS Host Config

Minimal host - k0s manages itself.

```nix
{
  # Bridge for LAN access
  networking.bridges.br0.interfaces = [ "enp3s0" ];
  networking.interfaces.br0.useDHCP = true;

  # k0s
  environment.systemPackages = [ pkgs.k0s ];

  # Firewall
  networking.firewall.allowedTCPPorts = [ 6443 ];

  # Gitea SSH allowlist (host-level, outside k8s)
  networking.nftables = {
    enable = true;
    tables.gitea-ssh = {
      family = "inet";
      content = ''
        chain input {
          type filter hook input priority 0;
          ip daddr 192.168.x.30 tcp dport 22 ip saddr { 192.168.x.100 } accept
          ip daddr 192.168.x.30 tcp dport 22 drop
        }
      '';
    };
  };

  # Sysctls
  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables" = 1;
    "net.ipv4.ip_forward" = 1;
  };
}
```

k0s.yaml:
```yaml
apiVersion: k0s.k0sproject.io/v1beta1
kind: ClusterConfig
metadata:
  name: homelab
spec:
  network:
    provider: calico
    calico:
      mode: iptables
```

## Container Hardening

| Pod | hostUsers | Storage | Capabilities | Notes |
|-----|-----------|---------|--------------|-------|
| hass | true | hostPath | NET_ADMIN, NET_RAW | mDNS via Multus |
| zwave-js | false | PVC | - | Connects to serial bridge |
| mqtt | false | PVC | - | Full isolation |
| postgres | false | PVC | - | Full isolation |
| gitea | false | PVC | - | Full isolation |
| jellyfin | false | hostPath (media) | - | Read-only media mount |
| file-server | false | hostPath | - | TBD |
| traefik (x2) | false | no | NET_BIND_SERVICE | Ports 80/443 |
| tailscale | false | no | NET_ADMIN | Tunnel |
| stepca | false | PVC | - | CA keys in secret |
| grafana | false | PVC | - | Full isolation |

All pods:
- `readOnlyRootFilesystem: true` (with tmpfs for /tmp if needed)
- `allowPrivilegeEscalation: false`
- Resource limits
- Seccomp: default or custom profile

## Open Questions

- [ ] Secrets: sealed-secrets, SOPS, external-secrets?
- [ ] GitOps: ArgoCD, Flux, or plain kubectl apply?
- [ ] Backup: Velero, or just backup etcd + PVs?
- [ ] StepCA root key: in-cluster secret? Vault? Offline?
- [ ] Monitoring: Prometheus? Or skip for homelab?
- [ ] File server: copyparty, seafile, nextcloud, plain SMB?
- [ ] Serial bridge: ESP32, Pi Zero, or repurpose old HA controller?
- [ ] Config sync: how to push NixOS configs from gitea?
