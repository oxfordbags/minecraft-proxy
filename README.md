# Minecraft Proxy

This is a collection of scripts to (hopefully) obscure a local IP address running a minecraft server on a custom domain name. It is suitable for Java and Bedrock servers.

## Installation

1. Point A record for the domain name to the IP address of the VPS.
2. Copy the `minecraft-proxy` directory to the home directory of the user on the VPS.
3. In `docker-compose.yml` replace `HOME_IP` with current IP address of the home network.
4. Run `docker-compose up -d` within the `minecraft-proxy` directory
5. Ensure ports `25565` and `19132` are fowarded to the server within the home network.
6. If the home network has a static IP address, the `minecraft-proxy-updater.sh` script can be run to update the VPS with the current IP address of the home network. Add as a cron job to update as regularly as needed.
