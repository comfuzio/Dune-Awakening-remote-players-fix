# Comfuzio's Native K3s External IP Fix for Dune: Awakening

An automated, clean, and native network routing configuration tool for self-hosted **Dune: Awakening** dedicated servers running inside a Kubernetes (**K3s / Ubuntu / Alpine**) environment.

## The Problem
When running a Dune: Awakening dedicated server inside K3s on a home network, the server nodes naturally bind to your local LAN IP (e.g., `192.168.x.x`). When the server communicates with Funcom's matchmaking master servers, it advertises this local IP. As a result, external players attempting to connect via your public IP are rejected because the K3s node does not natively recognize the external WAN IP as its own.

## The Solution
Instead of relying on messy `iptables` routing hacks or complex port interceptions, this script applies a **Native K3s Configuration**. It dynamically detects your network topology and explicitly instructs the K3s engine to adopt your Public WAN IP.

### Features
- **Clean-Room Implementation:** No hardcoded IPs, standard POSIX bash parsing.
- **Dynamic Topology Detection:** Automatically fetches your live Public WAN IP and your active internal Gateway LAN IP.
- **Native K3s Integration:** Modifies `/etc/rancher/k3s/config.yaml` to include `node-external-ip` and updates the `tls-san` certificates.
- **Safe Backups:** Automatically creates timestamped backups of your existing configurations before making any changes.
- **Smart Wait Loop:** Actively polls the K3s API during restart to confirm readiness, rather than using arbitrary sleep timers.
- **Automatic Validation:** Self-checks the final Kubernetes node state to guarantee the WAN IP is properly advertised.

---

## Prerequisites
- A self-hosted Dune: Awakening server running via **K3s**.
- Standard Linux utilities: `curl`, `awk`, `ip`.
- Root privileges (`sudo`).
- Proper Port Forwarding on your router (UDP 7777-7810 & TCP 31982 pointing to your host machine's local IP).

---

## Installation & Usage

1. Download the script to your server:
   ```bash
   nano comfuzio_k3s_native_fix.sh
   ```
2. Paste the script contents, save, and exit.

Make the script executable:
```
chmod +x comfuzio_k3s_native_fix.sh
```
Run the script with sudo:
```
sudo ./comfuzio_k3s_native_fix.sh
```
The script will automatically backup your config, apply the new IPs, restart the K3s engine, and validate the cluster. Give your pods 1-2 minutes to spin back up, and your server will be visible to the outside world!
