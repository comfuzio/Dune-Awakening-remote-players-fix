# Comfuzio's Native K3s External IP Fix for Dune: Awakening

An automated, clean, and native network routing configuration tool for self-hosted **Dune: Awakening** dedicated servers running inside a Kubernetes (**K3s**) environment on **Ubuntu**.

## The Problem
When running a Dune: Awakening dedicated server inside K3s on a home network, the server nodes naturally bind to your local LAN IP (e.g., `192.168.x.x`). When the server communicates with Funcom's matchmaking master servers, it advertises this local IP. As a result, external players attempting to connect via your public IP are rejected because the K3s node does not natively recognize the external WAN IP as its own, causing infinite loading screens during the Sector Handover process.

## The Solution
Instead of relying on messy `iptables` routing hacks, this script applies a **Native K3s Drop-in Configuration**. It dynamically detects your network topology, explicitly instructs the K3s engine to adopt your Public WAN IP, and **automatically recycles the Funcom Game Servers** to enforce the new network matrix.

### Features
- **Ubuntu Exclusive:** Explicit OS-Detection tailored for Ubuntu 22.04+ (Prevents destructive execution on unsupported distros like Alpine).
- **Safe Drop-in Configs:** Uses K3s `config.yaml.d/` standard instead of overwriting core engine configurations.
- **Automated Cluster Recycling:** Detects Funcom's `battlegroup.sh` and orchestrates a safe stop/start of the game pods so you don't have to restart them manually.
- **Dynamic Topology Detection:** Automatically fetches your live Public WAN IP and your active internal Gateway LAN IP.
- **Smart Wait Loop:** Actively polls the K3s API and Pod statuses to confirm readiness.
- **Automated Restore & Uninstall:** Includes a built-in uninstaller to revert your server exactly back to its original state if needed.

---

## Prerequisites
- A self-hosted Dune: Awakening server running via **K3s** on **Ubuntu (22.04 / 24.04 / 26.04+)**.
- Standard Linux utilities: `curl`, `awk`, `ip`.
- Root privileges (`sudo`).
- Proper Port Forwarding on your router:
  - **TCP 31982** (Master Server / Auth)
  - **UDP 7777-7810** (Sector Gates / Game Worlds)

*Note: If you are using Alpine Linux or another distribution, this script will intentionally block execution. Please refer to the [IEquilibriumI Dune Ansible Guide](https://github.com/IEquilibriumI/dune-selfhost-ansible) for alternative setups.*

---

## Installation & Usage

**1. Create the script file:**
```bash
nano comfuzio_k3s_native_fix.sh
```

2. Paste the script contents, save, and exit.

3. Make the script executable:
```bash
   chmod +x comfuzio_k3s_native_fix.sh
```
4. Run the script with sudo:
```
sudo ./comfuzio_k3s_native_fix.sh
```

## The Interactive Menu
Upon running the script, you will be presented with a simple menu:

1. External Mode: Applies the Public IP fix and recycles the server to allow internet players.

2. LAN-Only Mode: Removes the Public WAN configurations.

3. Restore & Uninstall: Safely removes the tool and restores your original Kubernetes configuration.

License
This project is licensed under the GNU Affero General Public License v3.0 (AGPL-3.0). This script comes with no warranty; use it at your own risk. If you encounter bugs related to the script's execution on Ubuntu, feel free to open an issue with your console logs.
