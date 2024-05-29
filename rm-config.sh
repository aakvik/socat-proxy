#!/bin/bash

parent_script_path=$(dirname "$0")

CONFIG_DIR="$parent_script_path/configs"
PID_FILE_DIR="/var/run"
SERVICE_TEMPLATE="socat@.service"

# Function to display usage
usage() {
	echo "Usage: $0 --source SOURCE --ipversion IPVERSION"
	exit 1
}

# Function to normalize IPv6 addresses
normalize_ipv6() {
	python3 -c "import ipaddress; print(ipaddress.IPv6Address('$1'))"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	--source)
		SOURCE="$2"
		shift 2
		;;
	--ipversion)
		IPVERSION="$2"
		shift 2
		;;
	*)
		echo "Unknown argument: $1"
		usage
		;;
	esac
done

# Check if the source and ipversion arguments are provided
if [ -z "$SOURCE" ] || [ -z "$IPVERSION" ]; then
	echo "Error: Missing source or ipversion argument"
	usage
fi

# Normalize the source IP address if it is IPv6
if [ "$IPVERSION" -eq 6 ]; then
	SOURCE=$(normalize_ipv6 "$SOURCE")
fi

# Define paths based on source IP
CONFIG_FILE="$CONFIG_DIR/${SOURCE}.json"
SERVICE_NAME="socat@${SOURCE}.service"
PID_FILE="${PID_FILE_DIR}/socat_${SOURCE}.pid"

# Stop and disable the systemd service
if systemctl is-active --quiet "$SERVICE_NAME"; then
	echo "Stopping service $SERVICE_NAME..."
	systemctl stop "$SERVICE_NAME"
fi

if systemctl is-enabled --quiet "$SERVICE_NAME"; then
	echo "Disabling service $SERVICE_NAME..."
	systemctl disable "$SERVICE_NAME"
fi

# Detect the interface dynamically
interface=$(ip route | grep default | awk '{print $5}')

if [ -z "$interface" ]; then
	echo "Error: Could not determine interface for IP $SOURCE"
	exit 1
fi

# Remove the IP address associated with the source
if [ "$IPVERSION" == "4" ]; then
	IP_DEL_CMD="ip addr del $SOURCE/24 dev $interface"
elif [ "$IPVERSION" == "6" ]; then
	IP_DEL_CMD="ip -6 addr del $SOURCE/64 dev $interface"
else
	echo "Error: Invalid IP version"
	exit 1
fi

echo "Removing IP address $SOURCE from $interface"
eval $IP_DEL_CMD

# Remove the configuration file
if [ -f "$CONFIG_FILE" ]; then
	echo "Removing configuration file $CONFIG_FILE..."
	rm -f "$CONFIG_FILE"
fi

# Remove the PID file if it exists
if [ -f "$PID_FILE" ]; then
	echo "Removing PID file $PID_FILE..."
	rm -f "$PID_FILE"
fi

# Reload systemd to apply changes
systemctl daemon-reload

echo "All configurations and services for IP $SOURCE have been removed."
