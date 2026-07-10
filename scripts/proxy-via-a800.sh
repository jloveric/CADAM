#!/usr/bin/env bash
# Share local CADAM over the a800 VPN IP (GatewayPorts is off, so we
# reverse-tunnel to localhost on a800, then proxy that out on 0.0.0.0).
#
# Usage:
#   npm run start:network          # CADAM on this laptop (default :3001)
#   PORT=13002 bash scripts/proxy-via-a800.sh
#
# Teammates open:
#   http://10.9.27.37:$PORT/cadam
#
# Optional:
#   LOCAL_PORT=3001   # CADAM port on this laptop (default 3001)
#   SSH_HOST=a800     # SSH config host (default a800)
set -euo pipefail

SSH_HOST="${SSH_HOST:-a800}"
LOCAL_PORT="${LOCAL_PORT:-3001}"
PORT="${PORT:?Set PORT to the public port teammates should use, e.g. PORT=13002 $0}"

# SSH -R can only bind localhost on a800; keep that off the public PORT.
TUNNEL_PORT=$((PORT + 10000))
if (( TUNNEL_PORT > 65535 )); then
  TUNNEL_PORT=$((PORT - 10000))
fi
if (( TUNNEL_PORT < 1024 || TUNNEL_PORT == PORT )); then
  echo "PORT=${PORT} leaves no valid internal tunnel port; pick another PORT." >&2
  exit 1
fi

SHARE_URL="http://10.9.27.37:${PORT}/cadam"

echo "Local CADAM:     127.0.0.1:${LOCAL_PORT}"
echo "SSH tunnel:      ${SSH_HOST} 127.0.0.1:${TUNNEL_PORT} -> this laptop :${LOCAL_PORT}"
echo "Public proxy:    0.0.0.0:${PORT} on ${SSH_HOST}"
echo "Share:           ${SHARE_URL}"
echo ""

# One SSH session: reverse-forward + run the public proxy remotely.
exec ssh \
  -o ExitOnForwardFailure=yes \
  -R "127.0.0.1:${TUNNEL_PORT}:127.0.0.1:${LOCAL_PORT}" \
  "${SSH_HOST}" \
  "PORT=${PORT} TUNNEL_PORT=${TUNNEL_PORT} python3 -" <<'PY'
import os
import socket
import threading

listen = ('0.0.0.0', int(os.environ['PORT']))
target = ('127.0.0.1', int(os.environ['TUNNEL_PORT']))


def pipe(src, dst):
  try:
    while data := src.recv(65536):
      dst.sendall(data)
  except Exception:
    pass
  finally:
    for sock in (src, dst):
      try:
        sock.close()
      except Exception:
        pass


def handle(client):
  upstream = socket.create_connection(target)
  threading.Thread(target=pipe, args=(client, upstream), daemon=True).start()
  pipe(upstream, client)


server = socket.socket()
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(listen)
server.listen(128)
print(f'proxy {listen[0]}:{listen[1]} -> {target[0]}:{target[1]}', flush=True)
print('ready', flush=True)
while True:
  client, _ = server.accept()
  threading.Thread(target=handle, args=(client,), daemon=True).start()
PY
