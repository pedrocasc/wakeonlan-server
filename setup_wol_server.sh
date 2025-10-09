#!/usr/bin/env bash
set -e

### --- CONFIGURABLE VARIABLES ---
PI_USER="pi"
APP_DIR="/home/${PI_USER}/wol-server"
APP_PORT=5000
APP_MAC="AA:BB:CC:DD:EE:FF"                # replace with your MAC address
PYTHON_PACKAGES="flask wakeonlan gunicorn psutil"

### --- INSTALL DEPENDENCIES ---
echo "[1/7] Installing dependencies..."
apt update -y && apt install -y python3 python3-venv python3-pip python3-dev build-essential \
                                libffi-dev libssl-dev nginx wakeonlan

### --- CREATE APP DIRECTORY ---
echo "[2/7] Creating app directory..."
mkdir -p "$APP_DIR"
cd "$APP_DIR"

### --- CREATE PYTHON VENV & INSTALL PACKAGES ---
echo "[3/7] Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install $PYTHON_PACKAGES
deactivate

### --- CREATE FLASK APP ---
echo "[4/7] Creating Flask app..."
cat > "$APP_DIR/app.py" <<PY
from flask import Flask, request
from wakeonlan import send_magic_packet
import psutil, time, logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)

DESKTOP_MAC = "${APP_MAC}"

@app.route("/wake", methods=["GET"])
def wake():
    try:
        send_magic_packet(DESKTOP_MAC)
        app.logger.info(f"Sent WOL packet to {DESKTOP_MAC}")
        return """
        <html>
        <head>
            <title>Computer on!</title>
            <style>
                body {
                    background-color: #0f111a;
                    color: #7dd3fc;
                    font-family: sans-serif;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    height: 100vh;
                    font-size: 3em;
                    text-align: center;
                }
            </style>
        </head>
        <body>
            <div>💻 Computer on!</div>
        </body>
        </html>
        """
    except Exception as e:
        app.logger.error(f"Error sending WOL packet: {e}")
        return f"<h3>Erro: {e}</h3>", 500

def get_stats():
    cpu = psutil.cpu_percent(interval=0.5)
    mem = psutil.virtual_memory().percent
    disk = psutil.disk_usage('/').percent
    with open('/proc/uptime') as f:
        uptime_seconds = float(f.readline().split()[0])
    uptime = time.strftime("%Hh %Mm %Ss", time.gmtime(uptime_seconds))
    try:
        with open('/sys/class/thermal/thermal_zone0/temp') as f:
            temp = int(f.readline()) / 1000
    except FileNotFoundError:
        temp = None
    return {"cpu": cpu, "memory": mem, "disk": disk, "uptime": uptime, "temperature": temp}

@app.route("/stats")
def stats():
    data = get_stats()
    temp_str = f"{data['temperature']:.1f}°C" if data['temperature'] else "N/A"
    return f"""
    <html>
    <head>
        <title>Raspberry Pi Stats</title>
        <style>
            body {{
                background-color: #0f111a;
                color: #e2e8f0;
                font-family: sans-serif;
                display: flex;
                justify-content: center;
                align-items: center;
                height: 100vh;
                margin: 0;
            }}
            .card {{
                background: #1e2230;
                padding: 2em 3em;
                border-radius: 20px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.3);
                text-align: center;
            }}
            h1 {{
                color: #7dd3fc;
                margin-bottom: 0.5em;
            }}
            p {{
                font-size: 1.2em;
                margin: 0.3em 0;
            }}
        </style>
    </head>
    <body>
        <div class="card">
            <h1>📊 Raspberry Pi Stats</h1>
            <p><b>CPU:</b> {data['cpu']}%</p>
            <p><b>Memory:</b> {data['memory']}%</p>
            <p><b>Disk:</b> {data['disk']}%</p>
            <p><b>Temperature:</b> {temp_str}</p>
            <p><b>Uptime:</b> {data['uptime']}</p>
        </div>
    </body>
    </html>
    """

@app.route("/")
def index():
    return "<h3>Wake-on-LAN Server</h3><ul><li><a href='/wake'>/wake</a></li><li><a href='/stats'>/stats</a></li></ul>"

if __name__ == "__main__":
    app.run(host="127.0.0.1", port=${APP_PORT})
PY

chown -R "$PI_USER":"$PI_USER" "$APP_DIR"
chmod -R 755 "$APP_DIR"

### --- CREATE SYSTEMD SERVICE ---
echo "[5/7] Creating systemd service..."
cat > /etc/systemd/system/wol-server.service <<SERVICE
[Unit]
Description=Wake-on-LAN Flask Server
After=network.target

[Service]
User=${PI_USER}
WorkingDirectory=${APP_DIR}
Environment="PATH=${APP_DIR}/venv/bin"
ExecStart=${APP_DIR}/venv/bin/gunicorn -b 127.0.0.1:${APP_PORT} app:app
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now wol-server

### --- CONFIGURE NGINX ---
echo "[6/7] Configuring nginx..."
cat > /etc/nginx/sites-available/wol <<NGINX
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${APP_PORT}/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/wol /etc/nginx/sites-enabled/wol
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl reload nginx

### --- DONE ---
echo "[7/7] ✅ Setup complete!"
IP=$(hostname -I | awk '{print $1}')
echo
echo "🌐 Access your server at: http://${IP}/"
echo "💡 Wake endpoint: http://${IP}/wake"
echo "📊 Stats endpoint: http://${IP}/stats"
echo
echo "If using Tailscale: use http://<your_tailscale_ip>/wake"
