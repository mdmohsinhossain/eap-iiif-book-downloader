#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python"

if command -v python3 >/dev/null 2>&1; then
    SYSTEM_PYTHON=python3
elif command -v python >/dev/null 2>&1; then
    SYSTEM_PYTHON=python
else
    echo "Error: Python 3 is required but was not found." >&2
    exit 1
fi

if [ ! -x "$VENV_PYTHON" ]; then
    "$SYSTEM_PYTHON" -m venv "$SCRIPT_DIR/.venv"
    "$VENV_PYTHON" -m pip install -r "$SCRIPT_DIR/requirements.txt"
fi

exec "$VENV_PYTHON" "$SCRIPT_DIR/get_eap_book.py" "$@"
