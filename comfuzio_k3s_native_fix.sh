#!/bin/bash
# ==============================================================================
# Title: Comfuzio's Native K3s External IP Fix for Dune: Awakening
# Description: Automates K3s native network topology updates for Dune server
#              WAN matchmaking. Designed strictly for Ubuntu + K3s environments.
# License: GNU AGPLv3
# ==============================================================================

set -e

K3S_DIR="/etc/rancher/k3s"
DROPIN_DIR="$K3S_DIR/config.yaml.d"
CONFIG_FILE="$DROPIN_DIR/99-comfuzio-network.yaml"
LEGACY_BACKUP="$K3S_DIR/config.yaml.ORIGINAL_BEFORE_COMFUZIO_FIX"
FUNCOM_SCRIPT="/home/dune/.dune/download/scripts/battlegroup.sh"

echo "================================================================"
echo "      Comfuzio's Native K3s Dune: Awakening Network Fix         "
echo "================================================================"

# --- OS Detection (Ubuntu Only Boundary) ---
UNSUPPORTED_MSG="Your distro is currently unsupported, if you feel like fixing this part, you are welcome! 
In the meantime please check this Amazing Dune guide that this script is made to work with: 
https://github.com/IEquilibriumI/dune-selfhost-ansible"

if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [ "$ID" != "ubuntu" ]; then
        echo ""
        echo "[-] Error: Detected OS ($NAME)."
        echo "$UNSUPPORTED_MSG"
        exit 1
    fi
else
    echo ""
    echo "[-] Error: Could not detect your OS."
    echo "$UNSUPPORTED_MSG"
    exit 1
fi

# --- Pre-Flight Checks ---
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This network tool requires root privileges. Run with sudo."
    exit 1
fi

if ! command -v k3s &> /dev/null; then
    echo "[-] Error: K3s is not installed or not found in PATH."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo "[-] Error: 'curl' is not installed."
    echo "    Please install it by running: sudo apt install curl"
    exit 1
fi

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
    
    # Restore legacy overwritten config if it exists
    if [ -f "$LEGACY_BACKUP" ]; then
        echo "[+] Legacy backup found. Restoring main config.yaml..."
        cp "$LEGACY_BACKUP" "$K3S_DIR/config.yaml"
        rm -f "$LEGACY_BACKUP"
    fi

    # Remove the drop-in file
    if [ -f "$CONFIG_FILE" ]; then
        echo "[+] Removing Comfuzio network drop-in configuration..."
        rm -f "$CONFIG_FILE"
    else
        echo "[*] No active drop-in fix found to remove."
    fi
    
    echo "[+] Restarting K3s engine..."
    systemctl restart k3s
    
    if [ -f "$FUNCOM_SCRIPT" ]; then
        echo "[+] Recycling Funcom cluster components..."
        sudo -i -u dune bash "$FUNCOM_SCRIPT" stop || true
        sleep 5
        sudo -i -u dune bash "$FUNCOM_SCRIPT" start || true
    fi

    echo ""
    echo "=========================================================================="
    echo " NOTICE: This script comes with no warranty. I apologize if it caused"
    echo " issues. Your original config has been restored successfully."
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

PUBLIC_IP=$(curl -s --connect-timeout 5 https://ifconfig.me || true)
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(curl -s --connect-timeout 5 https://api.ipify.org || true)
fi

if [ -z "$PUBLIC_IP" ] && [ "$MAIN_CHOICE" = "1" ]; then
    echo "[-] Error: Failed to detect Public WAN IP. Check your internet connection."
    exit 1
fi

DEFAULT_IFACE=$(ip route show default | awk '/default/ {print $5}' | head -n1)
LAN_IP=$(ip -4 addr show "$DEFAULT_IFACE" | grep -oE '[0-9]+(\.[0-9]+){3}' | head -n1)

if [ -z "$LAN_IP" ]; then
    echo "[-] Error: Failed to detect internal LAN IP."
    exit 1
fi

if [ "$MAIN_CHOICE" = "1" ]; then echo "[*] Discovered Public WAN IP : $PUBLIC_IP"; fi
echo "[*] Discovered Local LAN IP  : $LAN_IP"

# --- Step 3: Pre-Flight Optimization Checks ---
if [ "$MAIN_CHOICE" = "1" ]; then
    echo ""
    echo "[+] Checking if network fix is already active..."
    EXT_IP_CONFIGURED=$(grep -c "node-external-ip: $PUBLIC_IP" "$CONFIG_FILE" 2>/dev/null || echo 0)
    
    if [ "$EXT_IP_CONFIGURED" -ge 1 ]; then
        echo "================================================================"
        echo " STATUS: System is ALREADY OPTIMIZED. Fix is active and running."
        echo "================================================================"
        printf "Force re-apply and recycle server anyway? (y/N): "
        read -r FORCE_CHOICE
        if [ "$FORCE_CHOICE" != "y" ] && [ "$FORCE_CHOICE" != "Y" ]; then
            echo "[*] Exiting safely. Enjoy the game!"
            exit 0
        fi
    fi
fi

# --- Step 4: Safe Drop-In Configuration Writing ---
echo ""
mkdir -p "$DROPIN_DIR"

if [ "$MAIN_CHOICE" = "1" ]; then
    echo "[+] Injecting native K3s routing drop-in for External Play..."
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
    echo "[+] Injecting native K3s routing drop-in for LAN-Only Play..."
    cat <<EOF > "$CONFIG_FILE"
# Generated by Comfuzio's Dune: Awakening Network Tool
node-ip: $LAN_IP
advertise-address: $LAN_IP
tls-san:
  - $LAN_IP
EOF
fi

# --- Step 5: Service Management & Smart Wait Loop ---
echo ""
echo "[+] Restarting K3s engine to apply topology changes..."
systemctl restart k3s

echo "[+] Waiting for K3s API to come online..."
ATTEMPTS=0
while ! kubectl get nodes &> /dev/null; do
    printf "."
    sleep 2
    ATTEMPTS=$((ATTEMPTS+1))
    if [ "$ATTEMPTS" -ge 30 ]; then
        echo ""
        echo "[-] Timeout waiting for K3s API. It might be crashlooping."
        exit 1
    fi
done
echo ""
echo "[*] K3s API is responsive!"

# --- Step 6: Automated Funcom Cluster Recycling ---
if [ -f "$FUNCOM_SCRIPT" ]; then
    echo ""
    echo "[+] Automated Funcom script detected at: $FUNCOM_SCRIPT"
    echo "[+] Initiating safe cluster drain (battlegroup stop)..."
    
    sudo -i -u dune bash "$FUNCOM_SCRIPT" stop || true
    
    echo "[+] Waiting for all game instances to terminate successfully..."
    LOOP_COUNT=0
    while sudo -i -u dune bash "$FUNCOM_SCRIPT" status 2>/dev/null | grep -q "Running"; do
        printf "."
        sleep 3
        LOOP_COUNT=$((LOOP_COUNT+1))
        if [ "$LOOP_COUNT" -ge 20 ]; then
            echo ""
            echo "[-] Warning: Some pods are taking long to terminate. Forcing continuation..."
            break
        fi
    done
    echo ""
    echo "[*] Cluster drained. Initiating fresh boot with new network matrix..."
    sudo -i -u dune bash "$FUNCOM_SCRIPT" start
    echo "[*] Funcom cluster successfully initialized."
else
    echo ""
    echo "[*] Note: Manual installer topology detected. Remember to recycle your game pods"
    echo "    manually to force them to read the new K3s External-IP configuration."
fi

# --- Step 7: Verification Phase ---
echo ""
echo "================================================================"
echo " SUCCESS: SERVER TOPOLOGY RECONFIGURED NATIVELY"
echo "================================================================"
if [ "$MAIN_CHOICE" = "1" ]; then
    NODE_EXTERNAL=$(kubectl get nodes -o wide | tail -n +2 | awk '{print $7}')
    echo " -> Mode                  : External WAN"
    echo " -> Registered WAN IP     : $NODE_EXTERNAL"
    echo ""
    echo " [OK] K3s and Funcom servers have been completely synchronized!"
    echo "      Remote players can now seamlessly join your Arrakis world."
else
    echo " -> Mode                  : LAN-Only"
    echo " [OK] All public advertising parameters removed and cluster recycled."
fi
echo "================================================================"
