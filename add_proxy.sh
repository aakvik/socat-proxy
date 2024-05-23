#!/bin/bash

JSON_FILE="socat_config.json"

# Function to display usage
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

# Check if all arguments are provided
if [ -z "$SOURCE" ] || [ -z "$TARGET" ] || [ -z "$PORT" ] || [ -z "$PROTOCOL" ] || [ -z "$IPVERSION" ]; then
	echo "Error: Missing arguments"
	usage
fi

# Check if the JSON file exists, if not create it
if [ ! -f "$JSON_FILE" ]; then
	echo "{}" >$JSON_FILE
fi

# Check if the configuration already exists to avoid duplicates
EXISTING_CONFIG=$(jq --arg source "$SOURCE" --arg target "$TARGET" --arg port "$PORT" --arg protocol "$PROTOCOL" --arg ipversion "$IPVERSION" \
	'.[$source] | index({"target": $target, "port": $port, "protocol": $protocol, "ipversion": $ipversion})' $JSON_FILE)

if [ "$EXISTING_CONFIG" == "null" ]; then
	# Add the new configuration
	jq --arg source "$SOURCE" --arg target "$TARGET" --arg port "$PORT" --arg protocol "$PROTOCOL" --arg ipversion "$IPVERSION" \
		'.[$source] += [{"target": $target, "port": $port, "protocol": $protocol, "ipversion": $ipversion}]' $JSON_FILE >tmp.$$.json && mv tmp.$$.json $JSON_FILE
	echo "Configuration saved to $JSON_FILE"
else
	echo "Configuration already exists in $JSON_FILE"
fi
