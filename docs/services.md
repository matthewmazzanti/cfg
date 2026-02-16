# Homelab Services

Current and planned services for the homelab infrastructure.

## Deployed Services

### Server (`sys/server/`)

| Service | Type | Location | Access |
|---------|------|----------|--------|
| **Gitea** | Container (Quadlet) | `sys/server/gitea/` | `git.lan` (HTTP/HTTPS), SSH port 2222 |
| **Jellyfin** | Container (Quadlet) | `sys/server/jellyfin/` | `ssl.lan` via nginx reverse proxy |
| **Kiwix** | Container (Quadlet) | `sys/server/kiwix.nix` | `wiki.lan` (HTTP/HTTPS) |
| **Samba** | NixOS Service | `sys/server/samba.nix` | SMB3 port 445 |
| **Nginx** | NixOS Service | `sys/server/default.nix` | Ports 80, 443 |

### Home Automation (`sys/ha/`)

| Service | Type | Location | Access |
|---------|------|----------|--------|
| **Home Assistant** | Container (Quadlet) | `sys/ha/home-automation.nix` | Via nginx reverse proxy |
| **Matter Server** | Container (Quadlet) | `sys/ha/home-automation.nix` | Internal (Home Assistant) |
| **Z-Wave JS UI** | Container (Quadlet) | `sys/ha/home-automation.nix` | Internal (Home Assistant) |

## Provisional Services

Under consideration for future deployment.

### Core Infrastructure

| Service | Purpose | Notes |
|---------|---------|-------|
| **PostgreSQL** | Centralized database | Shared backend for Gitea, Home Assistant recorder, JuiceFS metadata |
| **Authentik** | Identity / SSO | Single sign-on for all services, 2FA, OIDC/SAML. Heavier but full-featured (alt: Authelia for lighter footprint) |
| **Tailscale** | Mesh VPN | Remote access to services, see isolation plan for proxy architecture |
| **StepCA** | Internal PKI | TLS certificates for all services, cert-manager integration |

### Monitoring & Notifications

| Service | Purpose | Notes |
|---------|---------|-------|
| **Prometheus** | Metrics collection | Node exporter, cAdvisor for containers, Home Assistant integration |
| **Grafana** | Metrics visualization | Dashboards for system and Home Assistant metrics |
| **InfluxDB** | Time-series database | Long-term Home Assistant history, sensor data retention |
| **Ntfy** | Push notifications | Service alerts, Home Assistant events, backup status. Self-hosted, mobile app |

### Applications

| Service | Purpose | Notes |
|---------|---------|-------|
| **Immich** | Photo management | Google Photos replacement, mobile backup, face recognition, GPU transcoding |
| **Recipe Management** | Meal planning / recipes | Options: Tandoor, Mealie, Grocy |
| **CalDAV/CardDAV** | Calendar & contacts sync | Options: Radicale (lightweight), Baikal, or full Nextcloud |
| **Document Management** | Searchable document archive | Paperless-ngx is standard but uses Tesseract. Investigate: LLM-based extraction, Apple Intelligence OCR pipeline, or custom workflow with vision models |

## Storage

### Current

- **Samba**: SMB3 file sharing at `/srv/files`
- **ZFS**: Two pools (`root-pool`, `data-pool`) with auto-scrub and trim

### Planned

#### JuiceFS

Distributed POSIX filesystem backed by object storage and metadata engine.

**Use cases:**
- Unified file storage across machines
- Cloud-backed storage with local caching
- Container persistent volumes

**Architecture:**
```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Client    │     │   Client    │     │   Client    │
│  (desktop)  │     │  (server)   │     │  (laptop)   │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌──────┴──────┐
                    │  Metadata   │
                    │   (Redis/   │
                    │  PostgreSQL)│
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │   Object    │
                    │   Storage   │
                    │ (MinIO/S3)  │
                    └─────────────┘
```

**Components needed:**
- Metadata engine: Redis or PostgreSQL
- Object storage: MinIO (self-hosted) or S3-compatible
- JuiceFS client on each machine

**NixOS integration:**
```nix
# Example mount configuration
fileSystems."/mnt/juice" = {
  device = "juicefs";
  fsType = "fuse.juicefs";
  options = [
    "META_URL"
    "_netdev"
    "allow_other"
  ];
};
```

## Network

| Machine | IP | VLAN |
|---------|-----|------|
| Server | `172.16.1.10/16` | VLAN 18 |
| Home Automation | `172.18.x.x/16` | Macvlan |

## Container Infrastructure

- **Runtime**: Podman with Quadlet systemd integration
- **Images**: Centralized in `lib/images.json`
- **Security**: User namespacing, read-only roots, dropped capabilities
- **Storage**: ZFS-backed persistent volumes
