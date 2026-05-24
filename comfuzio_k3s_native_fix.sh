#!/bin/bash
# ==============================================================================
# Title: Comfuzio's Native K3s External IP Fix for Dune: Awakening
# Description: Automates the native configuration of K3s to properly advertise 
#              a Public WAN IP for self-hosted matchmaking, completely bypassing 
#              the need for complex iptables routing hacks. Includes safe fallback.
# License: GNU AGPLv3
# ==============================================================================

set -e

K3S_DIR="/etc/rancher/k3s"
CONFIG_FILE="$K3S_DIR/config.yaml"
ORIGINAL_BACKUP="$K3S_DIR/config.yaml.ORIGINAL_BEFORE_COMFUZIO_FIX"

# --- Pre-Flight Checks ---
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This network tool requires root privileges. Run with sudo."
    exit 1
fi

if ! command -v k3s &> /dev/null; then
    echo "[-] Error: K3s is not installed or not found in PATH."
    exit 1
fi

echo "================================================================"
echo "      Comfuzio's Native K3s Dune: Awakening Network Fix         "
echo "================================================================"

# --- Step 1: Main Menu ---
echo "[+] Select Action:"
echo "1) External Mode (Allow internet players via Public IP)"
echo "2) LAN-Only Mode (Local network players only)"
echo "3) Restore Original Backup & Uninstall Fix"
printf "Enter choice (1-3): "
read -r MAIN_CHOICE

# --- Option 3: Restore Backup & Uninstall ---
if [ "$MAIN_CHOICE" = "3" ]; then
    echo ""
    echo "[+] Initializing Restore System..."
    if [ ! -f "$ORIGINAL_BACKUP" ]; then
        echo "[-] Error: Could not find your original backup file:"
        echo "    $ORIGINAL_BACKUP"
        echo "    It seems this script was never successfully run in External/LAN mode before."
        exit 1
    fi

    echo "[+] Restoring configuration to original state..."
    cp "$ORIGINAL_BACKUP" "$CONFIG_FILE"
    rm -f "$ORIGINAL_BACKUP"
    
    echo "[+] Restarting K3s engine to revert topology updates..."
    systemctl restart k3s
    
    echo ""
    echo "=========================================================================="
    echo " NOTICE: This script comes with no warranty. I apologize if it caused"
    echo " issues. Your original config has been restored successfully."
    echo " Everything is now exactly as if you had never run this script."
    echo "=========================================================================="
    echo " INFO: K3s logs have been saved in your system journal."
    echo " If you encountered a bug, please upload your logs as a GitHub Issue,"
    echo " providing your O/S details and all commands you executed before and after."
    echo " GitHub: https://github.com/YOUR_USERNAME/YOUR_REPOSITORY/issues"
    echo "=========================================================================="
    exit 0
fi

if [ "$MAIN_CHOICE" != "1" ] && [ "$MAIN_CHOICE" != "2" ]; then
    echo "[-] Invalid choice. Exiting."
    exit 1
fi

# --- Step 2: Dynamic IP Detection ---
echo ""
echo "[+] Detecting network topology..."

# Fetch Public IP
PUBLIC_IP=$(curl -s --connect-timeout 5 https://ifconfig.me)
if [ -z "$PUBLIC_IP" ]; then
    echo "[-] Warning: Primary API failed. Trying fallback..."
    PUBLIC_IP=$(curl -s --connect-timeout 5 https://api.ipify.org)
fi

if [ -z "$PUBLIC_IP" ]; then
    echo "[-] Error: Failed to detect Public WAN IP. Check your internet."
    exit 1
fi

# Fetch Active LAN IP
DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)
LAN_IP=$(ip -4 addr show "$DEFAULT_IFACE" | grep -oE '[0-9]+(\.[0-9]+){3}' | head -n1)

if [ -z "$LAN_IP" ]; then
    echo "[-] Error: Failed to detect internal LAN IP on interface $DEFAULT_IFACE."
    exit 1
fi

echo "[*] Discovered Public WAN IP : $PUBLIC_IP"
echo "[*] Discovered Local LAN IP  : $LAN_IP (via $DEFAULT_IFACE)"

# --- Step 3: Intelligent Backup Layer ---
mkdir -p "$K3S_DIR"

if [ -f "$CONFIG_FILE" ]; then
    # Create the immutable ORIGINAL backup if it doesn't exist
    if [ ! -f "$ORIGINAL_BACKUP" ]; then
        cp "$CONFIG_FILE" "$ORIGINAL_BACKUP"
        echo "[+] Protected original configuration backup saved as:"
        echo "    $ORIGINAL_BACKUP"
    fi
    # Create a regular incremental backup for safety
    INCREMENTAL_BACKUP="config.yaml.backup.$(date +%s)"
    cp "$CONFIG_FILE" "$K3S_DIR/$INCREMENTAL_BACKUP"
    echo "[+] Incremental backup saved as: $INCREMENTAL_BACKUP"
else
    # If no config.yaml exists at all, create an empty file as the ORIGINAL backup to track uninstallation
    touch "$ORIGINAL_BACKUP"
    echo "[*] No pre-existing K3s config found. Created empty baseline for safe uninstallation."
fi

# --- Step 4: Pre-Flight Optimization Checks ---
if [ "$MAIN_CHOICE" = "1" ]; then
    echo ""
    echo "[+] Checking if network fix is already active..."
    
    EXT_IP_CONFIGURED=$(grep -c "node-external-ip: $PUBLIC_IP" "$CONFIG_FILE" 2>/dev/null || echo 0)
    TLS_SAN_CONFIGURED=$(grep -c "- $PUBLIC_IP" "$CONFIG_FILE" 2>/dev/null || echo 0)

    if [ "$EXT_IP_CONFIGURED" -ge 1 ] && [ "$TLS_SAN_CONFIGURED" -ge 1 ]; then
        echo "================================================================"
        echo " STATUS: System is ALREADY OPTIMIZED. Fix is active and running."
        echo "================================================================"
        printf "Force re-apply configuration anyway? (y/N): "
        read -r FORCE_CHOICE
        if [ "$FORCE_CHOICE" != "y" ] && [ "$FORCE_CHOICE" != "Y" ]; then
            echo "[*] Exiting safely. Enjoy the game!"
            exit 0
        fi
        echo "[+] Force re-applying configurations..."
    fi
fi

# --- Step 5: Configuration Writing ---
echo ""
if [ "$MAIN_CHOICE" = "1" ]; then
    echo "[+] Generating native K3s routing configuration for External Play..."
    cat <<EOF > "$CONFIG_FILE"
# Generated by Comfuzio's Dune: Awakening Network Tool
node-ip: $LAN_IP
node-external-ip: $PUBLIC_IP
advertise-address: $LAN_IP
tls-san:
  - $PUBLIC_IP
  - $LAN_IP
EOF
else
    echo "[+] Generating native K3s routing configuration for LAN-Only Play..."
    cat <<EOF > "$CONFIG_FILE"
# Generated by Comfuzio's Dune: Awakening Network Tool
node-ip: $LAN_IP
advertise-address: $LAN_IP
tls-san:
  - $LAN_IP
EOF
fi

echo "[*] Configuration written successfully."

# --- Step 6: Service Management & Smart Wait Loop ---
echo ""
echo "[+] Restarting K3s engine to apply topology changes..."
systemctl restart k3s

echo "[+] Waiting for K3s API to come online..."
ATTEMPTS=0
MAX_ATTEMPTS=30

while ! kubectl get nodes &> /dev/null; do
    printf "."
    sleep 2
    ATTEMPTS=$((ATTEMPTS+1))
    if [ "$ATTEMPTS" -ge "$MAX_ATTEMPTS" ]; then
        echo ""
        echo "[-] Timeout: K3s took too long to respond. Please check 'systemctl status k3s'."
        exit 1
    fi
done

echo ""
echo "[*] K3s API is responsive!"

# --- Step 7: Verification Phase ---
echo ""
echo "================================================================"
echo " SUCCESS: SERVER TOPOLOGY RECONFIGURED NATIVELY"
echo "================================================================"
if [ "$MAIN_CHOICE" = "1" ]; then
    NODE_EXTERNAL=$(kubectl get nodes -o wide | tail -n +2 | awk '{print $7}')
    echo " -> Mode                  : External WAN"
    echo " -> Expected External IP  : $PUBLIC_IP"
    echo " -> K3s Registered IP     : $NODE_EXTERNAL"
    if [ "$PUBLIC_IP" = "$NODE_EXTERNAL" ]; then
        echo " [OK] The K3s node is now properly advertising to the internet."
    else
        echo " [WARNING] Mismatch detected. Check if your cluster has multiple nodes."
    fi
else
    echo " -> Mode                  : LAN-Only"
    echo " -> Local Ingress Endpoint: $LAN_IP"
    echo " [OK] All internet advertising options have been successfully removed."
fi
echo "================================================================"
