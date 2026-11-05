#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
MYMEMORY_TARGET="${MYMEMORY_TARGET:-sommonas}"
MYMEMORY_SSH_PORT="${MYMEMORY_SSH_PORT:-22}"
MYMEMORY_HOST_KEY_ALIAS="${MYMEMORY_HOST_KEY_ALIAS:-}"
MYMEMORY_SSH_KEY="${MYMEMORY_SSH_KEY:-$HOME/.ssh/id_ed25519}"
MYMEMORY_RELEASE="${MYMEMORY_RELEASE:-$(date -u +%Y%m%dT%H%M%SZ)}"
case "$MYMEMORY_RELEASE" in
  *[!a-zA-Z0-9_-]*|'') echo 'Invalid release identifier.' >&2; exit 1 ;;
esac
case "$MYMEMORY_SSH_PORT" in
  *[!0-9]*|'') echo 'Invalid SSH port.' >&2; exit 1 ;;
esac
if (( 10#$MYMEMORY_SSH_PORT < 1 || 10#$MYMEMORY_SSH_PORT > 65535 )); then
  echo 'Invalid SSH port.' >&2; exit 1
fi
case "$MYMEMORY_HOST_KEY_ALIAS" in
  *[!a-zA-Z0-9._:-]*) echo 'Invalid SSH host-key alias.' >&2; exit 1 ;;
esac
MYMEMORY_SSH_ARGS=(-o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=10 -p "$MYMEMORY_SSH_PORT" -i "$MYMEMORY_SSH_KEY")
if [ -n "$MYMEMORY_HOST_KEY_ALIAS" ]; then
  MYMEMORY_SSH_ARGS+=(-o "HostKeyAlias=$MYMEMORY_HOST_KEY_ALIAS")
fi
test -f server/package-lock.json || { echo 'Missing server/package-lock.json.' >&2; exit 1; }
test -f app/build/web/index.html || { echo 'Build Flutter web before deployment.' >&2; exit 1; }
node scripts/prepare-web.mjs
REMOTE_RELEASE="/srv/mymemory/releases/$MYMEMORY_RELEASE"
ssh "${MYMEMORY_SSH_ARGS[@]}" "$MYMEMORY_TARGET" "mkdir -p '$REMOTE_RELEASE'"
COPYFILE_DISABLE=1 tar --exclude='node_modules' --exclude='.env*' --exclude='.DS_Store' --exclude='__pycache__' --exclude='*.pyc' --exclude='*.log' --exclude='data' -czf - server deploy app/build/web |
  ssh "${MYMEMORY_SSH_ARGS[@]}" "$MYMEMORY_TARGET" "tar --no-same-owner -xzf - -C '$REMOTE_RELEASE'"
ssh "${MYMEMORY_SSH_ARGS[@]}" "$MYMEMORY_TARGET" bash -s -- "$MYMEMORY_RELEASE" <<'REMOTE'
set -euo pipefail
MYMEMORY_RELEASE="$1"
export MYMEMORY_RELEASE
release="/srv/mymemory/releases/$MYMEMORY_RELEASE"
previous="$(readlink -f /srv/mymemory/current 2>/dev/null || true)"
cd "$release"
account_override=/srv/mymemory/private/accounts.compose.yaml
compose_args=(-p mymemory -f deploy/compose.yaml)
if [ -f "$account_override" ]; then compose_args+=(-f "$account_override"); fi
docker compose "${compose_args[@]}" build --pull=false
docker compose "${compose_args[@]}" up -d --no-build
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
    rollback_args=(-p mymemory -f "$previous/deploy/compose.yaml")
    if [ -f "$account_override" ]; then rollback_args+=(-f "$account_override"); fi
    MYMEMORY_RELEASE="$(basename "$previous")" docker compose "${rollback_args[@]}" up -d --no-build
    echo 'Previous release restored.' >&2
  fi
  exit 1
fi
ln -sfn "$release" /srv/mymemory/current.new
mv -Tf /srv/mymemory/current.new /srv/mymemory/current
echo "MyMemory backend release $MYMEMORY_RELEASE healthy on 127.0.0.1:8798."
echo 'To install the HTTPS route: python3 /srv/mymemory/current/deploy/configure_proxy.py --apply'
REMOTE
