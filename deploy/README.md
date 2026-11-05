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

For deployment away from the home LAN, use the existing public SSH forwarding
endpoint supplied by the owner. It reaches the same NAS with the same key:

```sh
MYMEMORY_TARGET=michele@sommomi.cc MYMEMORY_SSH_PORT=222 \
  MYMEMORY_HOST_KEY_ALIAS=192.168.0.164 bash deploy/deploy.sh
ssh -p 222 -o StrictHostKeyChecking=yes -o HostKeyAlias=192.168.0.164 \
  -i "$HOME/.ssh/id_ed25519" michele@sommomi.cc \
  'python3 /srv/mymemory/current/deploy/configure_proxy.py'
```

`192.168.0.164` is the NAS's existing trusted host-key name in `known_hosts`,
also used by the LAN SSH configuration. Its ED25519 fingerprint is
`SHA256:kpcyrq3ietsLUECU2VQQfA04WrQ1w+T/jnvzrNoQhF8`. Public access was
verified against that existing key before authentication. Host-key checks remain
strict; neither unknown nor changed host keys are automatically accepted.
The script defaults to the `sommonas` LAN alias on port 22, with no alias override;
`MYMEMORY_SSH_KEY` optionally selects a key file, defaulting to
`$HOME/.ssh/id_ed25519`. These settings do not modify global SSH configuration.

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
