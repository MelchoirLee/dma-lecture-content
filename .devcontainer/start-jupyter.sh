#!/usr/bin/env bash
# Start JupyterLab on attach and print the URL to click.
#
# Idempotent: postAttachCommand runs every time you connect to the codespace, so
# this reuses an already-running server instead of starting a second one.
#
# Token authentication is left ON deliberately. Codespaces forwarded ports are
# private to you by default, but a port's visibility can be changed to public --
# and a token-less Jupyter server on a public port is remote code execution for
# anyone with the URL. The token costs one click and removes that risk.

set -euo pipefail
cd "$(dirname "$0")/.."

PORT=8888

# ---------------------------------------------------------------------------
# MongoDB for Lecture 32. Runs in this container on the default port, which is
# what MONGO_HOST points at. Data lives under $HOME so no root is needed and it
# survives a JupyterLab restart.
# ---------------------------------------------------------------------------
if command -v mongod >/dev/null 2>&1; then
  if ! pgrep -x mongod >/dev/null 2>&1; then
    mkdir -p "${HOME}/.mongodb-data"
    mongod --dbpath "${HOME}/.mongodb-data" \
           --logpath "${HOME}/.mongodb-data/mongod.log" \
           --bind_ip 127.0.0.1 --fork >/dev/null 2>&1 \
      && echo "MongoDB started (127.0.0.1:27017)" \
      || echo "WARNING: MongoDB failed to start; see ${HOME}/.mongodb-data/mongod.log"
  fi
fi

if jupyter server list 2>/dev/null | grep -q ":${PORT}/"; then
  echo "JupyterLab already running:"
else
  mkdir -p .devcontainer/logs
  nohup jupyter lab \
    --no-browser \
    --ip=0.0.0.0 \
    --port="${PORT}" \
    --ServerApp.root_dir="$(pwd)" \
    > .devcontainer/logs/jupyterlab.log 2>&1 &

  # Wait for the server to register itself.
  for _ in $(seq 1 40); do
    if jupyter server list 2>/dev/null | grep -q ":${PORT}/"; then break; fi
    sleep 0.5
  done
fi

# jupyter reports the bind address (0.0.0.0), which Codespaces will not turn
# into a clickable forwarded link. Rewrite it to a loopback host.
URL=$(jupyter server list 2>/dev/null | grep -o "http://[^ ]*:${PORT}/[^ ]*" | head -1 || true)
URL=${URL/0.0.0.0/127.0.0.1}

cat <<BANNER

  ┌──────────────────────────────────────────────────────────────┐
  │  DMA lecture decks — JupyterLab + RISE                       │
  └──────────────────────────────────────────────────────────────┘

  Open:  ${URL:-<starting, run ./start-jupyter.sh again>}

  Then:  open notebooks/lecture-05-….ipynb  and press  Alt+R
         (Option+R on macOS) to enter the slideshow.

         Space / →   next slide        ↓        sub-slides in a demo
         Shift+Enter run a code cell   Esc, o   slide overview

  Note:  RISE runs in JupyterLab, not in the VS Code notebook editor.
         Editing in VS Code is fine; presenting needs the link above.

BANNER
