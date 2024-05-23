#!/bin/bash

JSON_FILE="socat_config.json"
PID_FILE="socat_pids.txt"

# Function to bring up the source IP and run socat
# can we detect  $interface here in a good way?
run_socat() {
	local source="$1"
	local target="$2"
	local port="$3"
	local protocol="$4"
	local ipversion="$5"
	local interface="eth0"

	# Determine IP version and protocol
	if [ "$ipversion" == "4" ]; then
		IP_OPT="TCP4"
		IP_CMD="ip addr add $source/24 dev $interface"
		IP_CHECK="ip addr show dev $interface | grep -w $source"
	elif [ "$ipversion" == "6" ]; then
		IP_OPT="TCP6"
		IP_CMD="ip -6 addr add $source/64 dev $interface"
		IP_CHECK="ip -6 addr show dev $interface | grep -w $source"
	else
		echo "Error: Invalid IP version"
		return
	fi

	if [ "$protocol" == "tcp" ]; then
		PROTOCOL_OPT="TCP"
	elif [ "$protocol" == "udp" ]; then
		PROTOCOL_OPT="UDP"
	else
		echo "Error: Invalid protocol"
		return
	fi

	# Check if the source IP is already configured
	if eval $IP_CHECK >/dev/null 2>&1; then
		echo "Source IP $source is already configured on the interface $interface."
	else
		# Bring up the source IP
		echo "Bringing up source IP: $source on interface $interface"
		eval $IP_CMD
		if [ $? -ne 0 ]; then
			echo "Error: Failed to bring up source IP"
			return
		fi
		# run arping if $source gets configured on $interface
		arping -c 5 -A -I $interface $source
	fi

	# Create the socat command
	SOCAT_CMD="socat ${IP_OPT}-LISTEN:${port},fork,bind=${source} ${IP_OPT}:${target}:${port}"

	echo "Running socat command: $SOCAT_CMD"

	# Execute the socat command
	$SOCAT_CMD &
	echo $! >>$PID_FILE
}

# Read configurations from JSON file and run socat
for source in $(jq -r 'keys[]' $JSON_FILE); do
	jq -c --arg source "$source" '.[$source][]' $JSON_FILE | while read config; do
		target=$(echo $config | jq -r '.target')
		port=$(echo $config | jq -r '.port')
		protocol=$(echo $config | jq -r '.protocol')
		ipversion=$(echo $config | jq -r '.ipversion')

		run_socat "$source" "$target" "$port" "$protocol" "$ipversion"
	done
done
