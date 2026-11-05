# MyMemory on Sommonas

The app and multiplayer service share `https://mymemory.sommomi.cc`. Caddy
terminates HTTPS and proxies HTTP/WebSocket requests to `127.0.0.1:8798`.
No new public server ports are opened. DNS already points to the existing NAS.
Only the production browser origin is accepted; native Android/iOS clients also
use `/ws`. Caddy overwrites `X-Forwarded-For` with the actual remote client address
and is the sole public path to the private listener. `TRUST_PROXY=1` enables the
backend's per-address connection limits using that trusted header.

Build the web client in `app/`, run the server tests, then run:

```sh
bash deploy/deploy.sh
ssh sommonas 'python3 /srv/mymemory/current/deploy/configure_proxy.py'
ssh sommonas 'python3 /srv/mymemory/current/deploy/configure_proxy.py --apply'
```

The first proxy command is a read-only check. The second appends or updates only
the marked MyMemory block in the existing Caddyfile, checks for concurrent edits,
keeps a private backup, and reloads Caddy. It uses the existing Docker access in
a network-isolated helper with only `/etc/caddy` mounted. If Caddy rejects the
configuration, the script restores its previous configuration. It refuses to
replace disk configuration if the active runtime differs.

Each deployment is stored in `/srv/mymemory/releases/TIMESTAMP`, and `current`
points to the latest healthy release. The server runs as an unprivileged user
with a read-only image and web files. Runtime data is retained in the independent
Docker volume `mymemory-data`; never run `docker compose down -v` unless you intend
to erase it. Deployments restart the server. Clients can resume within the server's
90-second reconnect grace, but finishing ongoing games first avoids disruption.

Check deployment health:

```sh
curl -fsS https://mymemory.sommomi.cc/healthz
ssh sommonas 'docker inspect --format "{{.State.Health.Status}}" mymemory-api'
```

Rollback code (retains runtime data):

```sh
ssh sommonas
export MYMEMORY_RELEASE=PREVIOUS_TIMESTAMP
docker compose -p mymemory -f /srv/mymemory/releases/$MYMEMORY_RELEASE/deploy/compose.yaml up -d --no-build
ln -sfn /srv/mymemory/releases/$MYMEMORY_RELEASE /srv/mymemory/current.new
mv -Tf /srv/mymemory/current.new /srv/mymemory/current
```

Do not restore a full historical Caddyfile over changes made later by other apps.
To remove MyMemory, remove only the `BEGIN/END mymemory` block, validate and reload
Caddy, and stop only the `mymemory` Compose project. Existing sites are independent.
