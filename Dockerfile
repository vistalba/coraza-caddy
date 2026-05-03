FROM caddy:2-builder AS builder
RUN xcaddy build \
    --with github.com/corazawaf/coraza-caddy/v2

FROM caddy:2
RUN apk add --no-cache socat
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh && mkdir -p /var/log/coraza
ENTRYPOINT ["/entrypoint.sh"]
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
