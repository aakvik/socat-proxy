#!/bin/bash

CONFIG_DIR="configs"

# Function to display usage
# fix dump to usage when no args applied
usage() {
	echo "Usage: $0 --source SOURCE --target TARGET --port PORT --protocol PROTOCOL --ipversion IPVERSION"
	exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
	case "$1" in
	--source)
		SOURCE="$2"
		shift 2
		;;
	--target)
		TARGET="$2"
		shift 2
		;;
	--port)
		PORT="$2"
		shift 2
		;;
	--protocol)
		PROTOCOL="$2"
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

# Ensure the configuration directory exists
mkdir -p "$CONFIG_DIR"

# Create or update the configuration file for the source IP
CONFIG_FILE="$CONFIG_DIR/${SOURCE}.json"

# Check if the configuration file exists and is not empty
if [ -s "$CONFIG_FILE" ]; then
	# Append the new configuration to the existing ones
	jq --arg target "$TARGET" \
		--arg port "$PORT" \
		--arg protocol "$PROTOCOL" \
		--arg ipversion "$IPVERSION" \
		'. += [{"target": $target, "port": $port, "protocol": $protocol, "ipversion": $ipversion}]' \
		"$CONFIG_FILE" >tmp.$$.json && mv tmp.$$.json "$CONFIG_FILE"
else
	# Create a new configuration file with the new configuration
	jq -n --arg target "$TARGET" \
		--arg port "$PORT" \
		--arg protocol "$PROTOCOL" \
		--arg ipversion "$IPVERSION" \
		'[{"target": $target, "port": $port, "protocol": $protocol, "ipversion": $ipversion}]' \
		>"$CONFIG_FILE"
fi

echo "Configuration saved to $CONFIG_FILE"

# Reload systemd to pick up the new service
systemctl daemon-reload

# Enable and restart the service
SERVICE_NAME="socat@${SOURCE}.service"
if systemctl is-active --quiet "$SERVICE_NAME"; then
	systemctl reload-or-restart "$SERVICE_NAME"
	echo "Service $SERVICE_NAME reloaded or restarted."
else
	systemctl enable "$SERVICE_NAME"
	systemctl start "$SERVICE_NAME"
	echo "Service $SERVICE_NAME enabled and started."
fi
