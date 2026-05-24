#!/bin/sh
# Title: Comfuzio's Dune: Awakening allow remote players fix

# Ensure script runs as root
if [ "$(id -u)" -ne 0 ]; then
   echo "[-] Error: Please run this script as root (sudo ./setup_dune_net.sh)"
   exit 1
fi

echo "================================================================"
echo "         Comfuzio's Dune: Awakening Allow Remote Players Fix    "
echo "================================================================"

# Step 1: Mode Selection
echo "[+] Select Hosting Mode:"
echo "1) External Mode (Allow internet players via Public IP)"
echo "2) LAN-Only Mode (Local network players only)"
printf "Enter choice (1-2): "
read -r MODE_CHOICE

if [ "$MODE_CHOICE" != "1" ] && [ "$MODE_CHOICE" != "2" ]; then
    echo "[-] Invalid hosting mode selected. Exiting."
    exit 1
fi

# Step 2: Public IP Detection (Only needed for External Mode initially)
PUBLIC_IP=""
if [ "$MODE_CHOICE" = "1" ]; then
    echo ""
    echo "[+] Detecting Public IP via external API..."
    PUBLIC_IP=$(curl -s https://ifconfig.me)
    if [ -z "$PUBLIC_IP" ]; then
        echo "[-] Error: Could not detect your Public IP. Check your internet connection."
        exit 1
    fi
    echo "[*] Active Public IP detected: $PUBLIC_IP"
fi

# Step 3: Dynamic Interface Detection & Selection
echo ""
echo "[+] Scanning available LAN Network Interfaces..."
interfaces=$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo\|flannel\|cni\|veth')

printf "%-5s %-15s %-15s\n" "#" "Interface" "IP Address"
printf "%-5s %-15s %-15s\n" "---" "---------" "----------"

count=1
for iface in $interfaces; do
    ip_addr=$(ip -o -4 addr show "$iface" | awk '{print $4}' | cut -d/ -f1 | head -n1)
    if [ -n "$ip_addr" ]; then
        echo "$count)    $iface          $ip_addr"
        eval "iface_$count=\$iface"
        eval "ip_$count=\$ip_addr"
        count=$((count + 1))
    fi
done

echo ""
printf "Select network interface number: "
read -r IFACE_CHOICE

SELECTED_IFACE=$(eval echo "\$iface_$IFACE_CHOICE")
VM_PRIVATE_IP=$(eval echo "\$ip_$IFACE_CHOICE")

if [ -z "$SELECTED_IFACE" ]; then
    echo "[-] Error: Invalid network interface selection."
    exit 1
fi
echo "[*] Targeted Interface: $SELECTED_IFACE (Private IP: $VM_PRIVATE_IP)"

# Step 4: K3s Pod Automation Lookup
echo ""
echo "[+] Querying K3s cluster for 'mq-game' Pod IP..."
RABBITMQ_IP=$(kubectl get pods -A -o wide | grep "mq-game" | awk '{print $7}' | head -n1)

if [ -z "$RABBITMQ_IP" ] || [ "$RABBITMQ_IP" = "<none>" ]; then
    echo "[-] Error: K3s could not find 'mq-game' pod or the pod is pending an IP assignment."
    exit 1
fi
echo "[*] Found RabbitMQ Target Pod IP: $RABBITMQ_IP"

# Step 5: Pre-Flight Optimization Checks (Dynamic Switching)
if [ "$MODE_CHOICE" = "1" ]; then
    echo ""
    echo "[+] Checking if network fix is already active..."
    
    ALIAS_BOUND=0
    if ip addr show dev "$SELECTED_IFACE" | grep -q "$PUBLIC_IP"; then ALIAS_BOUND=1; fi

    UDP_RULE_EXISTS=0
    if iptables -t nat -C PREROUTING -d "$PUBLIC_IP" -p udp --dport 7777:7810 -j DNAT --to-destination "$VM_PRIVATE_IP" 2>/dev/null; then UDP_RULE_EXISTS=1; fi

    TCP_RULE_EXISTS=0
    if iptables -t nat -C PREROUTING -d "$PUBLIC_IP" -p tcp --dport 31982 -j DNAT --to-destination "$RABBITMQ_IP:5672" 2>/dev/null; then TCP_RULE_EXISTS=1; fi

    if [ "$ALIAS_BOUND" -eq 1 ] && [ "$UDP_RULE_EXISTS" -eq 1 ] && [ "$TCP_RULE_EXISTS" -eq 1 ]; then
        echo "================================================================"
        echo " STATUS: System is ALREADY OPTIMIZED. Fix is active and running."
        echo "================================================================"
        printf "Force re-apply rules anyway or switch to LAN-Only mode? (y/N/L): "
        read -r FORCE_CHOICE
        if [ "$FORCE_CHOICE" = "L" ] || [ "$FORCE_CHOICE" = "l" ]; then
            MODE_CHOICE="2"
            echo "[+] Switching to LAN-Only Mode..."
        elif [ "$FORCE_CHOICE" != "y" ] && [ "$FORCE_CHOICE" != "Y" ]; then
            echo "[*] Exiting safely. Enjoy the game!"
            exit 0
        else
            echo "[+] Force re-applying configurations..."
        fi
    else
        echo "[*] Changes or outdated rules detected. Proceeding with application..."
    fi

elif [ "$MODE_CHOICE" = "2" ]; then
    echo ""
    echo "[+] Checking if network is already in LAN-Only mode..."
    DETECTED_ALIAS=$(ip -o -4 addr show "$SELECTED_IFACE" | grep -v "$VM_PRIVATE_IP" | awk '{print $4}' | cut -d/ -f1 | head -n1)
    
    if [ -z "$DETECTED_ALIAS" ]; then
        echo "================================================================"
        echo " STATUS: System is ALREADY OPTIMIZED for LAN. No external bindings."
        echo "================================================================"
        printf "Force re-apply cleanup or switch to External WAN mode? (y/N/W): "
        read -r FORCE_CHOICE
        if [ "$FORCE_CHOICE" = "W" ] || [ "$FORCE_CHOICE" = "w" ]; then
            MODE_CHOICE="1"
            echo ""
            echo "[+] Switching to External Mode... Detecting Public IP..."
            PUBLIC_IP=$(curl -s https://ifconfig.me)
            if [ -z "$PUBLIC_IP" ]; then
                echo "[-] Error: Could not detect your Public IP."
                exit 1
            fi
            echo "[*] Active Public IP detected: $PUBLIC_IP"
        elif [ "$FORCE_CHOICE" != "y" ] && [ "$FORCE_CHOICE" != "Y" ]; then
            echo "[*] Exiting safely. Enjoy the game!"
            exit 0
        else
            echo "[+] Force re-applying LAN configurations..."
        fi
    else
        echo "[*] External bindings detected. Proceeding with cleanup..."
    fi
fi

# Step 6: Final Execution Flow
if [ "$MODE_CHOICE" = "1" ]; then
    # --- EXTERNAL MODE ROUTING ---
    echo ""
    echo "[+] Configuring networking for External Play..."
    
    if ip addr show dev "$SELECTED_IFACE" | grep -q "$PUBLIC_IP"; then
        echo "[*] Public IP alias is already bound to $SELECTED_IFACE."
    else
        echo "[+] Appending $PUBLIC_IP/32 secondary alias to $SELECTED_IFACE..."
        ip addr add "$PUBLIC_IP/32" dev "$SELECTED_IFACE"
    fi

    echo "[+] Purging stale iptables prerouting configurations..."
    iptables -t nat -D PREROUTING -d "$PUBLIC_IP" -p udp --dport 7777:7810 -j DNAT --to-destination "$VM_PRIVATE_IP" 2>/dev/null
    iptables -t nat -D PREROUTING -d "$PUBLIC_IP" -p tcp --dport 31982 -j DNAT --to-destination "$RABBITMQ_IP:5672" 2>/dev/null

    echo "[+] Inserting high-priority IPTables DNAT rules..."
    iptables -t nat -I PREROUTING 1 -d "$PUBLIC_IP" -p udp --dport 7777:7810 -j DNAT --to-destination "$VM_PRIVATE_IP"
    iptables -t nat -I PREROUTING 1 -d "$PUBLIC_IP" -p tcp --dport 31982 -j DNAT --to-destination "$RABBITMQ_IP:5672"

    echo ""
    echo "================================================================"
    echo " SUCCESS: EXTERNAL CONNECTIVITY REPAIRED"
    echo "================================================================"
    echo " Mode: External (Internet & WAN Matchmaking Enabled)"
    echo " Public Facing Address: $PUBLIC_IP"
    echo " Game Cluster (UDP 7777-7810) -> Routed to $VM_PRIVATE_IP"
    echo " RabbitMQ Sync (TCP 31982)    -> Intercepted to $RABBITMQ_IP:5672"
    echo "================================================================"

else
    # --- LAN ONLY MODE ROUTING ---
    echo ""
    echo "[+] Reverting network parameters to LAN-Only mode..."
    
    DETECTED_ALIAS=$(ip -o -4 addr show "$SELECTED_IFACE" | grep -v "$VM_PRIVATE_IP" | awk '{print $4}' | cut -d/ -f1 | head -n1)
    
    if [ -n "$DETECTED_ALIAS" ]; then
        echo "[+] Dropping public IP interface alias: $DETECTED_ALIAS..."
        ip addr del "$DETECTED_ALIAS/32" dev "$SELECTED_IFACE" 2>/dev/null
        
        echo "[+] Dropping associated IPTables prerouting modifications..."
        iptables -t nat -D PREROUTING -d "$DETECTED_ALIAS" -p udp --dport 7777:7810 -j DNAT --to-destination "$VM_PRIVATE_IP" 2>/dev/null
        iptables -t nat -D PREROUTING -d "$DETECTED_ALIAS" -p tcp --dport 31982 -j DNAT --to-destination "$RABBITMQ_IP:5672" 2>/dev/null
    else
        echo "[*] No active public IP network bindings detected on this interface."
    fi

    echo ""
    echo "================================================================"
    echo " SUCCESS: LOCAL LAN MODE RECONSTRUCTED"
    echo "================================================================"
    echo " Mode: LAN-Only (All external interception rules removed)"
    echo " Local Ingress Endpoint: $VM_PRIVATE_IP:7777"
    echo "================================================================"
fi
