#!/bin/bash

parent_script_path=$(dirname "$0")

CONFIG_DIR="$parent_script_path/configs"
PID_FILE_DIR="/var/run"
SERVICE_TEMPLATE="socat@.service"

# Function to display usage
usage() {
	echo "Usage: $0 --source SOURCE"
	exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	--source)
		SOURCE="$2"
		shift 2
		;;
	*)
		echo "Unknown argument: $1"
		usage
		;;
	esac
done

# Check if the source argument is provided
if [ -z "$SOURCE" ]; then
	echo "Error: Missing source argument"
	usage
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
