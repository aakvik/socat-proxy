#!/bin/bash

JSON_FILE="socat_config.json"
PID_FILE="socat_pids.txt"

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

# Function to take down the IP address
take_down_ip() {
	local source="$1"
	local ipversion="$2"
	local interface="eth0"

	if [ "$ipversion" == "4" ]; then
		IP_CMD="ip addr del $source/24 dev $interface"
	elif [ "$ipversion" == "6" ]; then
		IP_CMD="ip -6 addr del $source/64 dev $interface"
	else
		echo "Error: Invalid IP version"
		return 1
	fi

	echo "Taking down source IP: $source on interface $interface"
	eval $IP_CMD
	if [ $? -ne 0 ]; then
		echo "Error: Failed to take down source IP"
		return 1
	fi
}

# Stop socat processes associated with the source IP
if [ -f $PID_FILE ]; then
	while read pid; do
		if ps -p $pid >/dev/null 2>&1; then
			echo "Stopping socat process $pid"
			kill $pid
		fi
	done <$PID_FILE
	# Remove the PID file after stopping the processes
	rm -f $PID_FILE
fi

# Remove configurations from the JSON file and take down the IP addresses
configs=$(jq -c --arg source "$SOURCE" '.[$source][]' $JSON_FILE)

if [ -n "$configs" ]; then
	echo "$configs" | while IFS= read -r config; do
		ipversion=$(echo "$config" | jq -r '.ipversion')
		take_down_ip "$SOURCE" "$ipversion"
	done

	jq --arg source "$SOURCE" 'del(.[$source])' $JSON_FILE >tmp.$$.json && mv tmp.$$.json $JSON_FILE
	echo "Removed configurations for source IP $SOURCE from $JSON_FILE"
else
	echo "Error: No configurations found for source IP $SOURCE"
	exit 1
fi
