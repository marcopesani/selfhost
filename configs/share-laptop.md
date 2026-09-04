# Laptop access (red team)

The model is not a public URL. On your machine it is `http://127.0.0.1:18000` after an SSH tunnel. The pod still listens on `127.0.0.1:8000`; we forward to **18000** so we do not steal your local uvicorn.

## Once

1. Install [Tailscale](https://tailscale.com/download) (the app, kernel TUN). Log in to the team tailnet when invited.
2. Confirm `tailscale status` lists `glm-flash`. Do **not** open `http://<100.x>:8000`. If that works, stop and tell the operator — the ACL is wrong.
3. Copy [`ssh/glm-flash`](ssh/glm-flash) to `~/.ssh/config.d/glm-flash` and add this line **near the top** of `~/.ssh/config` (before any `Host` block):

   ```sshconfig
   Include ~/.ssh/config.d/glm-flash
   ```

   Or run `scripts/laptop-setup.sh` from a clone of this repo.
4. Export the inference bearer (not a Runpod API key):

   ```bash
   export GLM_API_KEY='…'
   export PI_OFFLINE=1
   ```

5. Point clients at loopback **18000**, model `glm-5.3-flash`, timeouts ≥ 20 min. Cursor will not work.

   - pi: merge [`pi-models.laptop.json`](pi-models.laptop.json) into `~/.pi/agent/models.json` (`baseUrl` `http://127.0.0.1:18000/v1`)
   - Codex: `OPENAI_BASE_URL=http://127.0.0.1:18000/v1` and `OPENAI_API_KEY=$GLM_API_KEY`
   - Claude Code: Anthropic base `http://127.0.0.1:18000`, same bearer

## Every sitting

```bash
tailscale status          # glm-flash listed
ssh -N glm-flash          # leave running; or: scripts/glm-up.sh
```

Smoke:

```bash
curl -sS -H "Authorization: Bearer $GLM_API_KEY" \
  http://127.0.0.1:18000/v1/models
```

Optional graphs: `http://127.0.0.1:18428/vmui`.

## If `tailscale ping glm-flash` works but `ssh glm-flash` hangs

A second VPN on your laptop (NordLynx, corporate clients, etc.) will blackhole Tailscale TCP. Disconnect it or split-tunnel; discovery pings are not the data plane.

## Never

- `curl http://100.x:8000` or any Tailscale IP on `:8000`
- `*.proxy.runpod.net`
- `/get_server_info` (prints the API key)
- Tailscale Serve / Funnel / SOCKS aimed at this API
- Sharing `RUNPOD_API_KEY`

One 512k GPU stream for the whole team. Short prompts can overlap; two full-window jobs queue.
