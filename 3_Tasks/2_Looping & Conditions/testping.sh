#!/bin/bash

SERVERS="servers.txt"

if [ ! -f "$SERVERS" ]; then
    echo "Error: servers.txt file not found!"
    exit 1
fi

while IFS= read IP || [ -n "$IP" ]; do
    if ping -c 1 -w 3 "$IP" &> /dev/null; then
        echo "Ping success [$IP]"
    else
        echo "Ping failed [$IP]"
    fi
done < "$SERVERS"