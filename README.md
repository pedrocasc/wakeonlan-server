# 🌐 Raspberry Pi Wake-on-LAN Server

A simple Flask + Nginx server that runs on a Raspberry Pi to remotely wake up your desktop computer using Wake-on-LAN (WOL).

It also provides a minimal `/stats` page showing your Pi's system stats such as CPU, memory, disk usage, uptime and temperature in static HTML page.

I made this project because a Raspberry Pi uses significantly less energy than a desktop computer and, that way, you don't need your desktop online 24/7.

---

## Features

- **Wake your desktop** by visiting `/wake`.
- **View Pi system stats** at `/stats`.
- **Auto-starts on boot** via systemd.
- **Works with Tailscale** to wake up your desktop remotely (no open ports needed).
- **Simple to set up** with a single script.

---

## Installation

> ⚠️ Tested on Raspberry Pi OS (13 Trixie). Should work on Debian based distros. Run as `sudo`.

```bash
sudo apt update
sudo apt install -y git
git clone https://github.com/pedrocasc/wakeonlan-server.git
cd wakeonlan-server
sudo ./setup_wol_server.sh
```
