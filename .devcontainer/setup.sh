#!/usr/bin/env bash
# One-time container setup: install the lecture runtime and make sure RISE
# cannot be broken by a conflicting JupyterLab extension.
#
# Runs as postCreateCommand, so students never type a pip command.

set -euo pipefail
cd "$(dirname "$0")/.."

# Install system-wide, not with --user.
#
# A --user install looks like it works but silently breaks RISE: pip drops
# jupyterlab_rise's server-extension config into ~/.local/etc/jupyter, which
# Jupyter does not scan (it reads ~/.jupyter and /usr/local/etc/jupyter). The
# extension then never registers, there is no /rise endpoint, and the slideshow
# cannot load. Installing as root puts the config in /usr/local/etc/jupyter and
# the entry points in /usr/local/bin, both already on the default path.
if ! command -v sudo >/dev/null 2>&1; then
  echo "ERROR: sudo not available; cannot install system-wide." >&2
  echo "       Run 'python -m pip install -r requirements.txt' as root." >&2
  exit 1
fi

echo "==> Installing lecture runtime"
sudo python -m pip install --quiet --upgrade pip
sudo python -m pip install --quiet -r requirements.txt

# ---------------------------------------------------------------------------
# Defensive guard.
#
# A clean image has none of these, so this file is a no-op there. It matters if
# the base image ever starts shipping them (or someone pip-installs ipywidgets
# or panel later): RISE's bundle does not provide the `@jupyterlab/console`
# shared module these extensions require, they throw during widget creation, and
# the slideshow renders as a blank white page with no visible error.
#
# Disabling them only affects JupyterLab's frontend. The Python packages keep
# working; you just cannot render an interactive widget onto a RISE slide, which
# RISE cannot do in any case.
# ---------------------------------------------------------------------------
echo "==> Writing RISE compatibility guard"
LABCONFIG="${HOME}/.jupyter/labconfig"
mkdir -p "$LABCONFIG"
cat > "${LABCONFIG}/page_config.json" <<'JSON'
{
  "disabledExtensions": {
    "@jupyter-widgets/jupyterlab-manager": true,
    "@pyviz/jupyterlab_pyviz": true,
    "@lckr/jupyterlab_variableinspector": true,
    "jupyterlab-plotly": true
  }
}
JSON

# ---------------------------------------------------------------------------
# MongoDB, for Lecture 32.
#
# The lecture connects with `MongoClient(os.getenv('MONGO_HOST'))` and seeds its
# own data from sample_enrollments.csv, so an empty local server is all it needs
# -- no dump to restore.
#
# Debian dropped MongoDB over its SSPL licence and no devcontainer Feature
# publishes the server (only client tools), so this installs from MongoDB's own
# apt repository, which does publish bookworm builds for amd64 and arm64.
# ---------------------------------------------------------------------------
if command -v mongod >/dev/null 2>&1; then
  echo "==> MongoDB server already present"
elif [ "$(dpkg --print-architecture)" != "amd64" ]; then
  # MongoDB publishes mongodb-org-server for amd64 only on Debian; the arm64
  # repo carries just client tools (mongosh, atlas-cli). GitHub Codespaces is
  # amd64, so this only affects local devcontainers on Apple Silicon.
  # Non-fatal on purpose: everything except Lecture 32's Mongo cells still works.
  echo "==> Skipping MongoDB: no Debian server package for $(dpkg --print-architecture)"
  echo "    Lecture 32's MongoDB cells will not run on this machine."
else
  echo "==> Installing MongoDB server"
  if (
    set -e
    # --batch --yes: postCreateCommand runs without a TTY, and plain `gpg`
    # tries to open /dev/tty and fails there.
    curl -fsSL https://pgp.mongodb.com/server-7.0.asc \
      | sudo gpg --batch --yes --dearmor \
          -o /usr/share/keyrings/mongodb-server-7.0.gpg
    echo "deb [ arch=amd64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] \
https://repo.mongodb.org/apt/debian bookworm/mongodb-org/7.0 main" \
      | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list >/dev/null
    # Refresh ONLY MongoDB's list. A plain `apt-get update` also re-reads the
    # yarn repository that ships in this base image, whose signing key is
    # missing -- that failure would abort the script under `set -e`.
    sudo apt-get update -qq \
      -o Dir::Etc::sourcelist="sources.list.d/mongodb-org-7.0.list" \
      -o Dir::Etc::sourceparts="-" \
      -o APT::Get::List-Cleanup="0"
    sudo apt-get install -y -qq mongodb-org-server >/dev/null
  ); then
    echo "    $(mongod --version | head -1)"
  else
    echo "    WARNING: MongoDB install failed; Lecture 32's Mongo cells will not run."
  fi
fi

# ---------------------------------------------------------------------------
# Presenting shortcut: Shift+Enter should run a cell without advancing the
# slide. See the header of the settings file for the reasoning.
# ---------------------------------------------------------------------------
echo "==> Installing presentation keyboard shortcuts"
SHORTCUTS="${HOME}/.jupyter/lab/user-settings/@jupyterlab/shortcuts-extension"
mkdir -p "$SHORTCUTS"
cp tools/rise-shortcuts.jupyterlab-settings \
   "${SHORTCUTS}/shortcuts.jupyterlab-settings"

# ---------------------------------------------------------------------------
# Smoke check: fail loudly now rather than mid-lecture.
# ---------------------------------------------------------------------------
echo "==> Verifying install"
python - <<'PY'
import sys, importlib.util
missing = [m for m in
           ("jupyterlab", "jupyterlab_rise", "numpy", "pandas", "matplotlib",
            "seaborn", "sklearn", "statsmodels", "pymongo")
           if not importlib.util.find_spec(m)]
if missing:
    sys.exit(f"FAIL: missing modules: {', '.join(missing)}")
print("    python modules OK")
PY

# `jupyter labextension list` colourises its output, so strip ANSI escapes
# before matching or the greps silently never hit.
LABEXT="$(jupyter labextension list 2>&1 | sed 's/\x1b\[[0-9;]*m//g')"

for ext in jupyterlab-rise dma-rise-run-button; do
  if echo "$LABEXT" | grep -q "${ext} v.* enabled OK"; then
    echo "    ${ext} labextension OK"
  else
    echo "    WARNING: ${ext} labextension not reported enabled:"
    echo "$LABEXT" | sed 's/^/      /'
  fi
done

if jupyter server extension list 2>&1 | grep -q "jupyterlab_rise.*OK"; then
  echo "    jupyterlab_rise server extension OK"
else
  echo "    WARNING: jupyterlab_rise server extension not reported OK"
fi

echo
echo "Setup complete. JupyterLab starts automatically; see the terminal for its URL."
