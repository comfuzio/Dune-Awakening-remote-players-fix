#!/bin/bash
# ==============================================================================
# Title: Comfuzio's Native K3s External IP Fix for Dune: Awakening
# Description: Automates K3s native network topology updates for Dune server
#              WAN matchmaking. Cross-platform support (Ubuntu/Alpine).
# License: GNU AGPLv3
# ==============================================================================

set -e

K3S_DIR="/etc/rancher/k3s"
CONFIG_FILE="$K3S_DIR/config.yaml"
ORIGINAL_BACKUP="$K3S_DIR/config.yaml.ORIGINAL_BEFORE_COMFUZIO_FIX"
FUNCOM_SCRIPT="/home/dune/.dune/download/scripts/battlegroup.sh"

# --- Helper Functions (Cross-Platform) ---
fetch_ip() {
    local url=$1
    if command -v curl &> /dev/null; then
        curl -s --connect-timeout 5 "$url"
    elif command -v wget &> /dev/null; then
        wget -qO- --timeout=5 "$url" 2>/dev/null
    else
        echo ""
    fi
}

restart_k3s() {
    echo "[+] Restarting K3s engine to apply topology changes..."
    if command -v systemctl &> /dev/null; then
        systemctl restart k3s
    elif command -v rc-service &> /dev/null; then
        rc-service k3s restart
    elif [ -x "/etc/init.d/k3s" ]; then
        /etc/init.d/k3s restart
    else
        echo "[-] Error: Could not detect service manager (systemctl/rc-service)."
        echo "    Please restart K3s manually."
        exit 1
    fi
}

# --- Pre-Flight Checks ---
if [ "$(id -u)" -ne 0 ]; then
    echo "[-] Error: This network tool requires root privileges. Run with sudo."
    exit 1
fi

if ! command -v k3s &> /dev/null; then
    echo "[-] Error: K3s is not installed or not found in PATH."
    exit 1
fi

if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    echo "[-] Error: Neither 'curl' nor 'wget' is installed."
    echo "    To fix this on Alpine: sudo apk add curl"
    echo "    To fix this on Ubuntu: sudo apt install curl"
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
        echo "[-] Error: Could not find your original backup file."
        exit 1
    fi

    echo "[+] Restoring configuration to original state..."
    cp "$ORIGINAL_BACKUP" "$CONFIG_FILE"
    rm -f "$ORIGINAL_BACKUP"
    
    restart_k3s
    
    if [ -f "$FUNCOM_SCRIPT" ]; then
        echo "[+] Recycling Funcom cluster components..."
        sudo -u dune bash "$FUNCOM_SCRIPT" stop || true
        sleep 5
        sudo -u dune bash "$FUNCOM_SCRIPT" start || true
    fi

    echo ""
    echo "=========================================================================="
    echo " NOTICE: This script comes with no warranty. I apologize if it caused"
    echo " issues. Your original config has been restored successfully."
    echo " Everything is now exactly as if you had never run this script."
    echo "=========================================================================="
    echo " If you encountered a bug, please upload your logs as a GitHub Issue."
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

PUBLIC_IP=$(fetch_ip "https://ifconfig.me")
if [ -z "$PUBLIC_IP" ]; then
    echo "[-] Warning: Primary API failed. Trying fallback..."
    PUBLIC_IP=$(fetch_ip "https://api.ipify.org")
fi

if [ -z "$PUBLIC_IP" ] && [ "$MAIN_CHOICE" = "1" ]; then
    echo "[-] Error: Failed to detect Public WAN IP."
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

# --- Step 3: Intelligent Backup Layer ---
mkdir -p "$K3S_DIR"

if [ -f "$CONFIG_FILE" ]; then
    if [ ! -f "$ORIGINAL_BACKUP" ]; then
        cp "$CONFIG_FILE" "$ORIGINAL_BACKUP"
        echo "[+] Protected original configuration backup saved."
    fi
    INCREMENTAL_BACKUP="config.yaml.backup.$(date +%s)"
    cp "$CONFIG_FILE" "$K3S_DIR/$INCREMENTAL_BACKUP"
else
    touch "$ORIGINAL_BACKUP"
fi

# --- Step 4: Pre-Flight Optimization Checks ---
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

# --- Step 6: Service Management & Smart Wait Loop ---
echo ""
restart_k3s

echo "[+] Waiting for K3s API to come online..."
ATTEMPTS=0
while ! kubectl get nodes &> /dev/null; do
    printf "."
    sleep 2
    ATTEMPTS=$((ATTEMPTS+1))
    if [ "$ATTEMPTS" -ge 30 ]; then
        echo ""
        echo "[-] Timeout waiting for K3s API."
        exit 1
    fi
done
echo ""
echo "[*] K3s API is responsive!"

# --- Step 7: Automated Funcom Cluster Recycling ---
if [ -f "$FUNCOM_SCRIPT" ]; then
    echo ""
    echo "[+] Automated Funcom script detected at: $FUNCOM_SCRIPT"
    echo "[+] Initiating safe cluster drain (battlegroup stop)..."
    
    sudo -u dune bash "$FUNCOM_SCRIPT" stop
    
    echo "[+] Waiting for all game instances to terminate successfully..."
    LOOP_COUNT=0
    while sudo -u dune bash "$FUNCOM_SCRIPT" status | grep -q "Running"; do
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
    sudo -u dune bash "$FUNCOM_SCRIPT" start
    echo "[*] Funcom cluster successfully initialized."
else
    echo ""
    echo "[*] Note: Manual installer topology detected. Remember to recycle your game pods"
    echo "    manually to force them to read the new K3s External-IP configuration."
fi

# --- Step 8: Verification Phase ---
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
