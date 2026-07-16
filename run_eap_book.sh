#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python"
DEPS_MARKER="$SCRIPT_DIR/.venv/.deps-ok"

# The marker is a copy of requirements.txt written only after a successful
# install, so a half-finished setup or changed requirements triggers a rebuild.
if [ -x "$VENV_PYTHON" ] && cmp -s "$SCRIPT_DIR/requirements.txt" "$DEPS_MARKER"; then
    exec "$VENV_PYTHON" "$SCRIPT_DIR/get_eap_book.py" "$@"
fi

if command -v python3 >/dev/null 2>&1; then
    SYSTEM_PYTHON=python3
elif command -v python >/dev/null 2>&1; then
    SYSTEM_PYTHON=python
else
    echo "Error: Python 3 is required but was not found." >&2
    exit 1
fi

rm -rf "$SCRIPT_DIR/.venv"
"$SYSTEM_PYTHON" -m venv "$SCRIPT_DIR/.venv"
"$VENV_PYTHON" -m pip install -r "$SCRIPT_DIR/requirements.txt"
cp "$SCRIPT_DIR/requirements.txt" "$DEPS_MARKER"

exec "$VENV_PYTHON" "$SCRIPT_DIR/get_eap_book.py" "$@"
