#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
MYMEMORY_TARGET="${MYMEMORY_TARGET:-sommonas}"
MYMEMORY_RELEASE="${MYMEMORY_RELEASE:-$(date -u +%Y%m%dT%H%M%SZ)}"
case "$MYMEMORY_RELEASE" in
  *[!a-zA-Z0-9_-]*|'') echo 'Invalid release identifier.' >&2; exit 1 ;;
esac
test -f server/package-lock.json || { echo 'Missing server/package-lock.json.' >&2; exit 1; }
test -f app/build/web/index.html || { echo 'Build Flutter web before deployment.' >&2; exit 1; }
REMOTE_RELEASE="/srv/mymemory/releases/$MYMEMORY_RELEASE"
ssh -o BatchMode=yes "$MYMEMORY_TARGET" "mkdir -p '$REMOTE_RELEASE'"
COPYFILE_DISABLE=1 tar --exclude='node_modules' --exclude='.env*' --exclude='.DS_Store' --exclude='__pycache__' --exclude='*.pyc' --exclude='*.log' --exclude='data' -czf - server deploy app/build/web |
  ssh -o BatchMode=yes "$MYMEMORY_TARGET" "tar --no-same-owner -xzf - -C '$REMOTE_RELEASE'"
ssh -o BatchMode=yes "$MYMEMORY_TARGET" bash -s -- "$MYMEMORY_RELEASE" <<'REMOTE'
set -euo pipefail
MYMEMORY_RELEASE="$1"
export MYMEMORY_RELEASE
release="/srv/mymemory/releases/$MYMEMORY_RELEASE"
previous="$(readlink -f /srv/mymemory/current 2>/dev/null || true)"
cd "$release"
docker compose -p mymemory -f deploy/compose.yaml build --pull=false
docker compose -p mymemory -f deploy/compose.yaml up -d --no-build
healthy=false
for attempt in $(seq 1 30); do
  if curl -fsS --max-time 3 http://127.0.0.1:8798/healthz >/dev/null; then
    healthy=true
    break
  fi
  sleep 1
done
if [ "$healthy" != true ]; then
  echo 'MyMemory health check failed.' >&2
  if [ -n "$previous" ] && [ -f "$previous/deploy/compose.yaml" ]; then
    MYMEMORY_RELEASE="$(basename "$previous")" docker compose -p mymemory -f "$previous/deploy/compose.yaml" up -d --no-build
    echo 'Previous release restored.' >&2
  fi
  exit 1
fi
ln -sfn "$release" /srv/mymemory/current.new
mv -Tf /srv/mymemory/current.new /srv/mymemory/current
echo "MyMemory backend release $MYMEMORY_RELEASE healthy on 127.0.0.1:8798."
echo 'To install the HTTPS route: python3 /srv/mymemory/current/deploy/configure_proxy.py --apply'
REMOTE
