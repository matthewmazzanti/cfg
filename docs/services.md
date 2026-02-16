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
| **PostgreSQL** | Centralized database | Shared backend for Gitea, Home Assistant recorder, JuiceFS metadata. SSL required, mTLS later |
| **Garage** | S3-compatible object storage | JuiceFS backend. Lightweight single binary, replaces MinIO (now in maintenance mode) |
| **Kanidm** | Identity / SSO | See [Identity & PKI](#identity--pki). Rust, lightweight, native NixOS provisioning |
| **StepCA** | Internal PKI | See [Identity & PKI](#identity--pki). OIDC provisioner for user certs |
| **Tailscale** | Mesh VPN | Remote access to services, see isolation plan for proxy architecture |

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

Distributed POSIX filesystem - translation layer over existing storage, not a storage system itself.

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
              ┌────────────┴────────────┐
              │                         │
       ┌──────┴──────┐           ┌──────┴──────┐
       │  Metadata   │           │   Object    │
       │ PostgreSQL  │           │   Storage   │
       │  (+ SSL)    │           │   Garage    │
       └─────────────┘           └─────────────┘
```

**Decisions:**
- **Metadata**: PostgreSQL (shared with Gitea, Home Assistant)
- **Object storage**: Garage (lightweight S3-compatible, single binary, ~20MB)
- **Auth**: Password + SSL (verify-full) initially, migrate to mTLS when StepCA ready
- **Encryption**: TLS in transit, disk encryption at rest (server-side)

**Why not Ceph/GlusterFS?**
- Ceph: 3+ nodes minimum, complex ops, overkill for single server
- GlusterFS: Deprecated by Red Hat, declining maintenance
- JuiceFS: Reuses existing infrastructure, complexity in backends not filesystem

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

## Identity & PKI

Layered approach: OIDC for identity, StepCA for certificates, mTLS for transport.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ Application Layer                                               │
│ → OIDC tokens, session cookies, user/group permissions          │
├─────────────────────────────────────────────────────────────────┤
│ Transport Layer                                                 │
│ → mTLS, certificate validation, cryptographic identity          │
└─────────────────────────────────────────────────────────────────┘

┌──────────┐   1. SSO Login   ┌──────────┐
│  User    │ ───────────────► │  Kanidm  │
│          │ ◄─────────────── │          │
└────┬─────┘   2. ID Token    └──────────┘
     │
     │ 3. Present token
     ▼
┌──────────┐
│  StepCA  │  Validates token, issues cert with identity
└────┬─────┘
     │
     │ 4. X.509 Certificate (identity in CN/SAN)
     ▼
   Client has PKI credential tied to OIDC identity
```

### Components

| Component | Role | Notes |
|-----------|------|-------|
| **Kanidm** | Identity source | OIDC provider, user auth, groups, 2FA, Unix PAM/NSS |
| **StepCA** | Certificate Authority | Issues certs, OIDC provisioner validates tokens before issuance |
| **mTLS** | Transport auth | Services verify client certs, no per-request token exchange |

### StepCA Provisioners

| Type | Use case |
|------|----------|
| **OIDC** | User certs - browser SSO flow, identity from token |
| **JWK** | Service/machine certs - password or automated |
| **ACME** | Web server certs - standard Let's Encrypt flow |

### Trust Flow

```
Kanidm (identity authority)
       │
       │ signs ID tokens (RFC 9068 JWT)
       ▼
   StepCA (validates tokens, issues certs)
       │
       │ signs X.509 certs
       ▼
   Services (validate certs via CA trust)
```

### Access Patterns

| Scenario | Auth method |
|----------|-------------|
| User → Web app | OIDC (browser SSO) |
| User → SSH/socket | Client cert (issued via OIDC flow) |
| Machine → Machine | mTLS (certs from JWK provisioner) |
| Service → Postgres | mTLS (cert CN = service identity) |
| External → Web | ACME certs (public TLS) |

### Decisions

- **OIDC Provider**: Kanidm
- **Certificate lifetime**: Short-lived (24h) for users, longer for services
- **Revocation**: CRL or OCSP via StepCA
- **Bootstrap**: JWK provisioner for initial machine enrollment

### Why Kanidm?

| | Kanidm | Authentik | Keycloak |
|---|--------|-----------|----------|
| **Language** | Rust | Python | Java |
| **RAM** | ~50-100MB | ~500MB | ~1GB+ |
| **Database** | Built-in | PostgreSQL + Redis | PostgreSQL |
| **NixOS** | Native module, declarative | Container | Container |
| **Unix auth** | PAM/NSS native | Weak | Weak |
| **Config** | Nix/CLI | Web UI + YAML | Web UI |

- Declarative OAuth2 clients in Nix config
- No external database dependencies
- Lightweight (Rust, built-in DB)
- Unix-first (SSH, sudo via PAM/NSS)
- Strict security defaults (PKCE required)

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
