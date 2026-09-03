#!/usr/bin/env bash
# Run the lecture decks locally with JupyterLab + RISE.
#
#   bash present.sh          # opens the file browser
#   bash present.sh 29       # opens lecture 29 directly
#   bash present.sh notebooks/lecture-29-....ipynb
#
# Mirrors .devcontainer/setup.sh + start-jupyter.sh, but for a local machine:
#   - installs into a private .venv instead of system-wide
#   - points Jupyter at an isolated config/data dir (.jupyter-rise/) instead of
#     ~/.jupyter, so this repo can't affect any other Jupyter project on your
#     machine and vice versa
#   - disables the extensions RISE can't load alongside (see requirements.txt
#     and README section 7) via that isolated config, not your real one
#
# Idempotent: reuses an already-running server on $PORT instead of starting a
# second one.

set -euo pipefail
cd "$(dirname "$0")"

PORT="${PORT:-8888}"
VENV=".venv"
ISOLATED=".jupyter-rise"

# A fresh, non-Anaconda interpreter if one is on the machine, since RISE's
# bundle can't load alongside the extensions Anaconda ships by default
# (jupyter-widgets, pyviz/panel, plotly, variableinspector -- see README §7).
# Falls back to whatever `python3` resolves to if not.
PYBIN="python3"
for candidate in /usr/local/bin/python3 /opt/homebrew/bin/python3; do
  if [ -x "$candidate" ]; then
    PYBIN="$candidate"
    break
  fi
done

if [ ! -d "$VENV" ]; then
  echo "==> Creating virtual environment ($VENV) with $PYBIN"
  "$PYBIN" -m venv "$VENV"
fi

PIP="$VENV/bin/pip"
JUPYTER="$VENV/bin/jupyter"

echo "==> Installing lecture runtime"
"$PIP" install --quiet --upgrade pip
"$PIP" install --quiet -r requirements.txt

echo "==> Writing isolated Jupyter config ($ISOLATED)"
export JUPYTER_CONFIG_DIR="$(pwd)/$ISOLATED/config"
export JUPYTER_DATA_DIR="$(pwd)/$ISOLATED/data"
# Lets JupyterLab discover the prebuilt run-button extension committed under
# tools/jupyter-data/labextensions without installing it into the venv.
export JUPYTER_PATH="$(pwd)/tools/jupyter-data"

LABCONFIG="$JUPYTER_CONFIG_DIR/labconfig"
mkdir -p "$LABCONFIG"
cat > "$LABCONFIG/page_config.json" <<'JSON'
{
  "disabledExtensions": {
    "@jupyter-widgets/jupyterlab-manager": true,
    "@pyviz/jupyterlab_pyviz": true,
    "@lckr/jupyterlab_variableinspector": true,
    "jupyterlab-plotly": true
  }
}
JSON

SHORTCUTS="$JUPYTER_CONFIG_DIR/lab/user-settings/@jupyterlab/shortcuts-extension"
mkdir -p "$SHORTCUTS"
cp tools/rise-shortcuts.jupyterlab-settings "$SHORTCUTS/shortcuts.jupyterlab-settings"

# MongoDB for Lecture 32, if you have a local server installed. Non-fatal if
# not -- everything except Lecture 32's Mongo cells still works.
if command -v mongod >/dev/null 2>&1 && ! pgrep -x mongod >/dev/null 2>&1; then
  mkdir -p "$ISOLATED/mongodb-data"
  mongod --dbpath "$(pwd)/$ISOLATED/mongodb-data" \
         --logpath "$(pwd)/$ISOLATED/mongodb-data/mongod.log" \
         --bind_ip 127.0.0.1 --fork >/dev/null 2>&1 \
    && echo "==> MongoDB started (127.0.0.1:27017)" \
    || echo "==> WARNING: MongoDB failed to start; Lecture 32's Mongo cells will not run."
fi

if "$JUPYTER" server list 2>/dev/null | grep -q ":${PORT}/"; then
  echo "JupyterLab already running:"
else
  mkdir -p "$ISOLATED/logs"
  nohup "$JUPYTER" lab \
    --no-browser \
    --ip=127.0.0.1 \
    --port="${PORT}" \
    --ServerApp.root_dir="$(pwd)" \
    > "$ISOLATED/logs/jupyterlab.log" 2>&1 &
  disown

  for _ in $(seq 1 40); do
    if "$JUPYTER" server list 2>/dev/null | grep -q ":${PORT}/"; then break; fi
    sleep 0.5
  done
fi

TOKEN=$("$JUPYTER" server list 2>/dev/null \
        | grep -o "http://[^ ]*:${PORT}/[^ ]*token=[A-Za-z0-9]*" \
        | head -1 | sed -n 's/.*token=//p' || true)

NB_PATH=""
if [ $# -gt 0 ]; then
  if [ -f "$1" ]; then
    NB_PATH="$1"
  else
    NUM=$(printf "%02d" "$1" 2>/dev/null || echo "$1")
    NB_PATH=$(ls notebooks/lecture-"${NUM}"-*.ipynb 2>/dev/null | head -1 || true)
    if [ -z "$NB_PATH" ]; then
      echo "No lecture matching '$1'; linking to the file browser instead." >&2
    fi
  fi
fi

LAB_PATH="/lab"
[ -n "$NB_PATH" ] && LAB_PATH="/lab/tree/${NB_PATH}"

URL="http://127.0.0.1:${PORT}${LAB_PATH}?token=${TOKEN}"
[ -n "$TOKEN" ] || URL=""

if [ -n "$NB_PATH" ]; then
  OPENS="opens $(basename "$NB_PATH")"
else
  OPENS="opens the file browser; pass a lecture number to open one directly"
fi

cat <<BANNER

  ┌──────────────────────────────────────────────────────────────┐
  │  DMA lecture decks — JupyterLab + RISE (local)                │
  └──────────────────────────────────────────────────────────────┘

  Open:  ${URL:-<still starting -- run the command again in a few seconds>}

         (${OPENS})

  Then:  press  Alt+R  (Option+R on macOS) to enter the slideshow.

         Space / →   next slide        ↓        sub-slides in a demo
         Shift+Enter run a code cell   Esc, o   slide overview

BANNER
