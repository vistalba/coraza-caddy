# coraza-caddy

A multi-architecture Docker image combining [Caddy](https://caddyserver.com/) with [Coraza WAF](https://coraza.io/) and the [OWASP Core Rule Set (CRS)](https://coreruleset.org/). Designed as a reverse proxy sidecar with built-in Web Application Firewall and optional syslog forwarding for audit logs.

## Features

- **Caddy + Coraza WAF** with OWASP CRS out of the box
- **Multi-arch support:** `linux/amd64`, `linux/arm64`, `linux/arm/v7`
- **Syslog forwarding** of WAF audit logs via UDP (e.g., to Graylog, rsyslog)
- **Fallback to stdout** when no syslog target is configured (`kubectl logs` compatible)
- **Built-in log rotation** (truncates to last 1000 lines every hour)
- **Lightweight** – based on Alpine

## Features

- **Caddy + Coraza WAF** with OWASP CRS out of the box
- **Multi-arch support:** `linux/amd64`, `linux/arm64`, `linux/arm/v7`
- **Syslog forwarding** of WAF audit logs via UDP (e.g., to Graylog, rsyslog)
- **Fallback to stdout** when no syslog target is configured (`kubectl logs` compatible)
- **Built-in log rotation** (truncates to last 1000 lines every hour)
- **Lightweight** – based on Alpine

## Environment Variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `SYSLOG_TARGET` | No | *(empty)* | UDP syslog destination (`host:port`). If unset, audit logs are written to stdout. |

## Caddyfile Example

```caddyfile
{
  order coraza_waf first
  auto_https off
  admin off
}

:8080 {
  coraza_waf {
    load_owasp_crs
    directives `
      Include @coraza.conf-recommended
      Include @crs-setup.conf.example
      Include @owasp_crs/*.conf
      SecRuleEngine On
      SecRequestBodyAccess On
      SecResponseBodyAccess Off
      SecRequestBodyLimit 10485760
      SecRequestBodyNoFilesLimit 131072
      SecAuditEngine RelevantOnly
      SecAuditLogParts ABCFHZ
      SecAuditLogFormat JSON
      SecAuditLog /var/log/coraza/audit.log
    `
  }
  reverse_proxy localhost:5055
}

:8081 {
  respond /health 200
}
```

## Kubernetes Sidecar Usage

This image is designed to run as a sidecar container in a Kubernetes pod, sitting in front of your application container:

`Client → Ingress Controller → Service (port 80) → Coraza-Caddy (:8080) → App (:5055)`

### Pod Configuration

```yaml
containers:
  - name: coraza-waf
    image: vistalba/coraza-caddy:latest
    ports:
      - name: http
        containerPort: 8080
      - name: health
        containerPort: 8081
    env:
      - name: SYSLOG_TARGET
        value: "10.0.0.1:1515"
    volumeMounts:
      - name: caddyfile
        mountPath: /etc/caddy/Caddyfile
        subPath: Caddyfile
      - name: coraza-logs
        mountPath: /var/log/coraza
    readinessProbe:
      httpGet:
        path: /health
        port: 8081
      initialDelaySeconds: 5
      periodSeconds: 10
    livenessProbe:
      httpGet:
        path: /health
        port: 8081
      initialDelaySeconds: 10
      periodSeconds: 15

  - name: app
    image: your-app:latest
    ports:
      - containerPort: 5055
```
The Kubernetes Service should target port 8080 (Coraza-Caddy), not the application port directly.

## Syslog Behavior

| `SYSLOG_TARGET` | Audit Log Destination | `kubectl logs` Output |
|---|---|---|
| Set (e.g., `10.0.0.1:1515`) | UDP syslog | Caddy startup logs only |
| Unset or empty | stdout | WAF audit logs visible |

Audit logs are JSON-formatted, one event per line – compatible with Graylog, Elasticsearch, Splunk, and similar log aggregators.

## Log Rotation

A background process truncates the audit log file to the last 1000 lines every hour. This prevents disk exhaustion when using `emptyDir` volumes in Kubernetes (recommended: `sizeLimit: 50Mi`).

## Performance Tuning

For applications with heavy static asset traffic, disable WAF processing and audit logging for non-critical paths in your Caddyfile:

```SecRule REQUEST_URI “@rx .(js|css|png|jpg|jpeg|gif|ico|svg|woff2?|ttf|eot|map)(?.*)?$”
“id:10000,phase:1,pass,nolog,ctl:ruleEngine=Off,ctl:auditEngine=Off”```

## Building

```bash
docker buildx build \
  --platform linux/amd64,linux/arm64,linux/arm/v7 \
  -t your-registry/coraza-caddy:latest \
  . --push
```

## License

This image bundles open-source components:
- [Caddy](https://github.com/caddyserver/caddy) – Apache 2.0
- [Coraza](https://github.com/corazawaf/coraza) – Apache 2.0
- [OWASP CRS](https://github.com/coreruleset/coreruleset) – Apache 2.0
