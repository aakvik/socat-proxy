#!/bin/bash

parent_script_path=$(dirname "$0")

CONFIG_FILE="$parent_script_path/configs/$1.json"
PID_FILE="/var/run/socat_${1}.pid"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Configuration file $CONFIG_FILE not found!"
    exit 1
fi

# Function to normalize IPv6 addresses
normalize_ipv6() {
    python3 -c "import ipaddress; print(ipaddress.IPv6Address('$1'))"
}

# Function to bring up the source IP and run socat
run_socat() {
    local source="$1"
    local target="$2"
    local port="$3"
    local protocol="$4"
    local ipversion="$5"
    local interface

    # Normalize the source and target IP addresses if they are IPv6
    if [ "$ipversion" == "6" ]; then
        source=$(normalize_ipv6 "$source")
        target=$(normalize_ipv6 "$target")
    fi

    # Detect the interface dynamically
    interface=$(ip route | grep default | awk '{print $5}')

    if [ -z "$interface" ]; then
        echo "Error: Could not determine interface for IP $source"
        return
    fi

    # Determine IP version and protocol
    if [ "$ipversion" == "4" ]; then
        if [ "$protocol" == "tcp" ]; then
            IP_OPT="TCP4"
        elif [ "$protocol" == "udp" ]; then
            IP_OPT="UDP4"
        else
            echo "Error: Invalid protocol"
            return
        fi
        IP_CMD="ip addr add $source/24 dev $interface"
        IP_CHECK="ip addr show dev $interface | grep -w $source"
    elif [ "$ipversion" == "6" ]; then
        if [ "$protocol" == "tcp" ]; then
            IP_OPT="TCP6"
        elif [ "$protocol" == "udp" ]; then
            IP_OPT="UDP6"
        else
            echo "Error: Invalid protocol"
            return
        fi
        IP_CMD="ip -6 addr add $source/64 dev $interface"
        IP_CHECK="ip -6 addr show dev $interface | grep -w $source"
    else
        echo "Error: Invalid IP version"
        return
    fi

    # Check if the source IP is already configured
    if eval $IP_CHECK >/dev/null 2>&1; then
        echo "Source IP $source is assigned to $interface."
    else
        # Bring up the source IP
        echo "Bringing up source IP: $source on $interface"
        eval $IP_CMD
        if [ $? -ne 0 ]; then
            echo "Error: Failed to bring up source IP"
            return
        fi
        # Run arping if $source gets configured on $interface
        arping -c 5 -A -I $interface $source
    fi

    # Create the socat command
    SOCAT_CMD="socat ${IP_OPT}-LISTEN:${port},fork,bind=${source} ${IP_OPT}:[${target}]:${port}"

    echo "Running socat command: $SOCAT_CMD"

    # Execute the socat command
    $SOCAT_CMD &
    echo $! >>$PID_FILE
}

# Read configurations from JSON file and run socat
source_ip=$(basename "$CONFIG_FILE" .json)
jq -c '.[]' "$CONFIG_FILE" | while read -r config; do
    target=$(echo $config | jq -r '.target')
    port=$(echo $config | jq -r '.port')
    protocol=$(echo $config | jq -r '.protocol')
    ipversion=$(echo $config | jq -r '.ipversion')

    run_socat "$source_ip" "$target" "$port" "$protocol" "$ipversion"
done
