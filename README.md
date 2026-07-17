# Minecraft Proxy

A tiny nginx TCP/UDP proxy that fronts a home Minecraft server behind a VPS, so
players connect to a public domain and never see the home network's IP address.
Works for both Java and Bedrock servers.

The home server (`home-server`) reaches the VPS over [Tailscale](https://tailscale.com),
so the proxy points at a **stable tailnet IP that never changes** — no dynamic-DNS
or IP-update tooling is required, and the home router needs no port forwarding.

## How it works

```
player ──▶ your.domain ──▶ VPS (public IP) ──▶ nginx ──▶ 100.64.0.1 (home-server, over Tailscale)
```

Players only ever see the VPS IP. The backend address (set via `.env`, see below)
is the home server's Tailscale CGNAT address, which is meaningless outside the
tailnet — the real home IP appears nowhere on the VPS.

## Installation

1. **DNS** — Point an A record for your domain at the VPS's public IP.

2. **Put the VPS on the tailnet.** On the VPS:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```
   Approve the new node in the Tailscale admin console. Confirm it can reach the
   home server: `tailscale ping home-server`.

3. **Install Docker** on the VPS if needed:
   ```bash
   curl -fsSL https://get.docker.com | sh
   ```

4. **Deploy the proxy.** Copy the `minecraft-proxy/` directory to the VPS, set the
   backend address, and start it:
   ```bash
   cd minecraft-proxy
   cp .env.example .env        # then edit BACKEND_IP if the backend isn't home-server
   docker compose up -d
   ```
   `BACKEND_IP` is the backend server's stable Tailscale IP (`tailscale ip -4` on
   that machine). nginx renders `templates/nginx.conf.template` with this value at
   startup, so nothing is hardcoded. If the IP ever changes, edit `.env` and re-run
   `docker compose up -d`.

5. **Open the VPS firewall** for the game ports:
   - `25565/tcp` and `25565/udp` (Java)
   - `19132/udp` (Bedrock)

6. **Close the home router port forwards.** Once players can connect through the
   VPS, remove any `25565` / `19132` forwards on the home router — inbound traffic
   now arrives only over the tailnet, which closes the direct-to-home attack path.
