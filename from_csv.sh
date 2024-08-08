#!/bin/bash

# Ports to proxy
ports=(80 443 22 3389)

# Check if an IP is v4
is_ipv4() {
    local ip=$1
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check if an IP is v6
is_ipv6() {
    local ip=$1
    if [[ $ip =~ ^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$ || \
          $ip =~ ^([0-9a-fA-F]{1,4}:){1,7}:$ || \
          $ip =~ ^::([0-9a-fA-F]{1,4}:){1,6}[0-9a-fA-F]{1,4}$ || \
          $ip =~ ^([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$ || \
          $ip =~ ^([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}$ || \
          $ip =~ ^([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}$ || \
          $ip =~ ^([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}$ || \
          $ip =~ ^([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}$ || \
          $ip =~ ^[0-9a-fA-F]{1,4}:(:[0-9a-fA-F]{1,4}){1,6}$ || \
          $ip =~ ^::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4}$ || \
          $ip =~ ^::([0-9a-fA-F]{1,4}:){0,6}$ ]]; then
        return 0
    else
        return 1
    fi
}
# Check if an input file is provided
if [ -z "$1" ]; then
    echo "Error: No input file provided."
    echo "Usage: $0 <input_file>"
    exit 1
fi

# Check if the provided file exists
if [ ! -f "$1" ]; then
    echo "Error: File '$1' not found."
    echo "Usage: $0 <input_file>"
    exit 1
fi

input_file="$1"

while read -r source target net hostname; do
    # Skipping mgt
    third_block=$(echo "$net" | awk '{print $3}')
    if [[ $third_block == *mgt* ]]; then
        continue
    fi

    # Extract IP addresses from the source
    for ip in $source; do
        # Check if v4 or v6
        if is_ipv4 "$ip"; then
            ipversion="4"
        elif is_ipv6 "$ip"; then
            ipversion="6"
        else
            continue
        fi

        for port in "${ports[@]}"; do
            ./add_config.sh --source "$source" --target "$target" --port "$port" --protocol tcp --ipversion "$ipversion"
        done
    done
done < "$input_file"
