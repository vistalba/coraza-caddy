#!/bin/sh
set -e

AUDIT_LOG="/var/log/coraza/audit.log"
touch "$AUDIT_LOG"

if [ -n "$SYSLOG_TARGET" ]; then
  # Forward to Graylog via UDP
  tail -F "$AUDIT_LOG" | socat - UDP-SENDTO:"${SYSLOG_TARGET}" &
else
  # Fallback: stdout (kubectl logs)
  tail -F "$AUDIT_LOG" &
fi

# Log rotation: truncate to last 1000 lines every hour
while true; do
  sleep 3600
  if [ -f "$AUDIT_LOG" ]; then
    tail -1000 "$AUDIT_LOG" > "$AUDIT_LOG.tmp" && mv "$AUDIT_LOG.tmp" "$AUDIT_LOG"
  fi
done &

exec "$@"
