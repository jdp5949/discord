#!/usr/bin/env bash
# Bash + curl — works anywhere curl is installed.
#
# Usage:
#   DISCORD_WEBHOOK=https://discord.com/api/webhooks/.../...  ./send.sh
#
# Includes 429 Retry-After backoff via curl -w.

set -euo pipefail

: "${DISCORD_WEBHOOK:?Set DISCORD_WEBHOOK env var}"

send() {
  local payload="$1"
  local max_retries=5
  local attempt=1
  while (( attempt <= max_retries )); do
    local resp body code
    body=$(curl -s -o /tmp/discord_resp.$$ -w "%{http_code}" \
      -X POST -H "Content-Type: application/json" \
      -d "$payload" "$DISCORD_WEBHOOK")
    code=$body
    if [[ "$code" =~ ^2 ]]; then
      rm -f /tmp/discord_resp.$$
      return 0
    fi
    if [[ "$code" == "429" ]]; then
      # Parse retry_after using jq if available, else default to 1s
      local wait
      if command -v jq >/dev/null; then
        wait=$(jq -r '.retry_after // 1' /tmp/discord_resp.$$)
      else
        wait=1
      fi
      sleep "$(awk "BEGIN { print $wait + 0.05 }")"
      attempt=$((attempt + 1))
      continue
    fi
    if (( code >= 500 )) && (( attempt < max_retries )); then
      sleep 1
      attempt=$((attempt + 1))
      continue
    fi
    echo "ERROR: HTTP $code" >&2
    cat /tmp/discord_resp.$$ >&2
    rm -f /tmp/discord_resp.$$
    return 1
  done
  rm -f /tmp/discord_resp.$$
  return 1
}

# Use a HEREDOC so embedded quotes don't fight the shell parser.
read -r -d '' PAYLOAD <<'JSON' || true
{
  "username": "shell-bot",
  "embeds": [{
    "title": "Backup completed",
    "description": "Nightly Postgres dump finished",
    "color": 53606,
    "fields": [
      {"name": "Size",     "value": "12.4 GB",     "inline": true},
      {"name": "Duration", "value": "8m 14s",      "inline": true},
      {"name": "Target",   "value": "s3://backups", "inline": true}
    ],
    "footer": {"text": "cron / backup.sh"}
  }]
}
JSON

send "$PAYLOAD"
echo "sent"
