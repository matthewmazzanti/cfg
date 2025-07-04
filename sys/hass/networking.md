* VLANs:
  * VLAN 1 (172.16.0.0/20): Internal access, port 443 exposed here only
  * VLAN 18 (172.18.0.0/20): Outbound access only for Home Assistant

* Networks:
  * ha-internal: 192.168.100.0/24, internal-only Podman bridge, no gateway
  * ha-macvlan: 172.18.0.240/28, macvlan on `enp1s0.18`, used only for egress

* Containers:
  * hass (Home Assistant):
    * Dual NICs: 192.168.100.2 (bridge) and 172.18.0.241 (macvlan)
    * Accepts connections only from nginx
    * Egress traffic goes out via VLAN 18
  * zwave:
    * Single NIC: 192.168.100.3
    * No internet access; reachable only by hass and nginx
  * nginx:
    * Single NIC: 192.168.100.4
    * Listens on 172.16.0.10:443 (VLAN 1 only)
    * Proxies to hass:8123, zwave:3000, zwave:8091

* Internal DNS:
  * Provided by Netavark
  * Containers resolve each other by name (hass, zwave, nginx)

* Startup Order:
  * hass depends on `enp1s0.18.device` for macvlan to function
