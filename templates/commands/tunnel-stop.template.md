
<!-- CODEX-OVERRIDE:START -->
# tunnel-stop — Codex Runtime

Stop any running tunnel processes.

```bash
# Kill localtunnel
pkill -f "localtunnel" 2>/dev/null || echo "No localtunnel running"

# Kill ngrok
pkill -f "ngrok" 2>/dev/null || echo "No ngrok running"

# Kill cloudflared
pkill -f "cloudflared" 2>/dev/null || echo "No cloudflared running"
```

Tell me which tunnel you started and I'll stop it cleanly.
<!-- CODEX-OVERRIDE:END -->
---
description: Stop the running tunnel service
model: haiku
---

# /tunnel-stop - Stop Development Tunnel

Stop the currently running tunnel service and clean up.

{{#if (neq devEnvironment.tunnel.service "none")}}

## Stop Commands

{{#if (eq devEnvironment.tunnel.service "ngrok")}}
### ngrok

```bash
# Find ngrok process
{{#if (eq process.platform "win32")}}
tasklist | findstr ngrok
{{else}}
pgrep -f ngrok
{{/if}}

# Kill ngrok
{{#if (eq process.platform "win32")}}
taskkill /IM ngrok.exe /F
{{else}}
pkill ngrok
{{/if}}

# Or use ngrok API
curl -X DELETE http://localhost:{{devEnvironment.tunnel.adminPort}}/api/tunnels/<tunnel-name>
```
{{/if}}

{{#if (eq devEnvironment.tunnel.service "localtunnel")}}
### localtunnel

```bash
# Find and kill localtunnel process
{{#if (eq process.platform "win32")}}
taskkill /IM node.exe /F  # Warning: kills all Node processes
{{else}}
pkill -f localtunnel
{{/if}}
```

Or simply press Ctrl+C in the terminal running localtunnel.
{{/if}}

{{#if (eq devEnvironment.tunnel.service "cloudflare-tunnel")}}
### Cloudflare Tunnel

```bash
# Find and kill cloudflared
{{#if (eq process.platform "win32")}}
taskkill /IM cloudflared.exe /F
{{else}}
pkill cloudflared
{{/if}}
```

Or press Ctrl+C in the terminal running cloudflared.
{{/if}}

{{#if (eq devEnvironment.tunnel.service "serveo")}}
### Serveo

Simply close the SSH connection or press Ctrl+C.
{{/if}}

## Clean Up

After stopping, clear the tunnel URL from configuration:

```json
{
  "devEnvironment": {
    "tunnel": {
      "url": null
    }
  }
}
```

## Instructions for Claude

When this command is invoked:

1. Identify running tunnel processes
2. Offer to kill the process
3. Clear tunnel URL from tech-stack.json
4. Confirm tunnel is stopped

{{else}}

## No Tunnel Configured

No tunnel service is configured. Run `/menu` → Project Settings → Tunnel Services to set up.

{{/if}}

---

*Generated from tech-stack.json template*
