#!/bin/sh

AUDIT_LOG="/var/log/coraza/audit.log"
: > "$AUDIT_LOG"

# === Syslog Forwarder ===
forward_logs() {
  LAST_SIZE=0
  while true; do
    CURR_SIZE=$(stat -c %s "$AUDIT_LOG" 2>/dev/null || echo 0)
    if [ "$CURR_SIZE" -gt "$LAST_SIZE" ]; then
      BYTES_NEW=$((CURR_SIZE - LAST_SIZE))
      tail -c "$BYTES_NEW" "$AUDIT_LOG" | \
        while IFS= read -r line; do
          [ -n "$line" ] && printf '%s\n' "$line" | socat - UDP-SENDTO:"${SYSLOG_TARGET}" 2>/dev/null
        done
      LAST_SIZE=$CURR_SIZE
    elif [ "$CURR_SIZE" -lt "$LAST_SIZE" ]; then
      LAST_SIZE=0
    fi
    sleep 1
  done
}

if [ -n "$SYSLOG_TARGET" ]; then
  forward_logs &
else
  tail -F "$AUDIT_LOG" &
fi

# === Log Rotation ===
(
  while true; do
    sleep 3600
    if [ -f "$AUDIT_LOG" ] && [ "$(wc -l < "$AUDIT_LOG")" -gt 1000 ]; then
      tail -1000 "$AUDIT_LOG" > "$AUDIT_LOG.tmp" && mv "$AUDIT_LOG.tmp" "$AUDIT_LOG"
    fi
  done
) &

exec "$@"
