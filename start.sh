#!/usr/bin/env bash
set -euo pipefail
cd backend
python -m pip install --disable-pip-version-check --quiet -r requirements.txt
exec python -m uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8080}"
