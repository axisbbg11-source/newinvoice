#!/usr/bin/env bash
set -euo pipefail
cd backend
python3 -m pip install --disable-pip-version-check --quiet -r requirements.txt
exec python3 -m uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8080}"
