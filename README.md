# Comfuzio's Dune: Awakening Allow Remote Players Fix

An automated, intelligent network routing solution for hosting a self-hosted **Dune: Awakening** dedicated server inside a lightweight Kubernetes (**K3s / Alpine / Ubuntu**) environment.

## The Problem
When running a Dune: Awakening dedicated server inside K3s, the server pods operate on an internal overlay network (e.g., `10.42.x.x`). Due to Funcom's master server IP validation and internal K3s `kube-proxy` load balancing, external players attempting to connect via your router's Port Forwarding are often rejected because the incoming packets do not match a locally bound interface IP on the host VM, or they fail to reach the internal RabbitMQ sync pod properly.

## The Solution
This script acts as an automated network engineering tool that dynamically repairs the routing topology in real-time. 

### Features
- **Dynamic Public IP Detection:** Automatically fetches your current external WAN IP.
- **Interactive Interface Mapping:** Scans and prompts you to select the correct host network interface.
- **K3s Pod Automation Lookup:** Queries the cluster to instantly locate the active `mq-game` (RabbitMQ) pod internal IP.
- **Smart-State Detection:** Checks if the system is already optimized to prevent duplicate rule injection.
- **High-Priority Interception:** Uses `iptables` NAT prerouting to bypass proxy bottlenecks and deliver traffic directly to the components.
- **On-the-Fly Switching:** Allows toggling between **External WAN Mode** and **LAN-Only Mode** instantly with clean routing environment purges.

---

## Prerequisites
Before running the script, ensure your environment has the following installed:
- `curl`
- `iptables`
- `kubectl` (configured and authenticated to your K3s instance)
- Root privileges (`sudo`)

Make sure your edge router (e.g., UniFi UCG-Fiber) is forwarding **UDP 7777-7810** and **TCP 31982** to your VM's private IP.

---

## Installation & Usage

1. Clone or download the script to your server VM:
   ```bash
   nano setup_dune_net.sh
