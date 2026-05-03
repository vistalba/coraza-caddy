#!/bin/sh

AUDIT_LOG="/var/log/coraza/audit.log"
: > "$AUDIT_LOG"

# === Syslog Forwarder ===
forward_logs() {
  LAST_POS=0
  while true; do
    CURR_POS=$(wc -c < "$AUDIT_LOG")
    if [ "$CURR_POS" -gt "$LAST_POS" ]; then
      dd if="$AUDIT_LOG" bs=1 skip="$LAST_POS" 2>/dev/null | \
        while IFS= read -r line; do
          [ -n "$line" ] && printf '%s\n' "$line" | socat - UDP-SENDTO:"${SYSLOG_TARGET}" 2>/dev/null
        done
      LAST_POS=$CURR_POS
    elif [ "$CURR_POS" -lt "$LAST_POS" ]; then
      LAST_POS=0
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
