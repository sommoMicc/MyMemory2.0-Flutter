#!/usr/bin/env python3
"""Install just the MyMemory site in the existing NAS Caddy configuration.

Run on Sommonas. Default is read-only validation; --apply writes and reloads.
Docker grants write access only to /etc/caddy in a network-isolated helper.
"""
import argparse
import hashlib
import json
import subprocess
import tempfile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

CONFIG = Path('/etc/caddy/Caddyfile')
ADMIN = 'http://127.0.0.1:2019'
IMAGE = 'node:24.22.1-bookworm-slim'
BEGIN = '# BEGIN mymemory'
END = '# END mymemory'


def adapt(text):
    with tempfile.NamedTemporaryFile(suffix='.caddyfile') as file:
        file.write(text.encode())
        file.flush()
        result = subprocess.run(
            ['caddy', 'adapt', '--config', file.name, '--adapter', 'caddyfile'],
            text=True, capture_output=True, check=True,
        )
        # Caddy automatically hides the source Caddyfile from file_server. A
        # temporary validation file must keep the real file's exclusion path.
        def source_path(value):
            if isinstance(value, dict):
                return {key: source_path(item) for key, item in value.items()}
            if isinstance(value, list):
                return [source_path(item) for item in value]
            return str(CONFIG) if value == file.name else value
        return source_path(json.loads(result.stdout))


def active_config():
    with urllib.request.urlopen(ADMIN + '/config/', timeout=10) as response:
        return json.load(response)


def load_config(config):
    request = urllib.request.Request(
        ADMIN + '/load', data=json.dumps(config).encode(),
        headers={'Content-Type': 'application/json'}, method='POST',
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        response.read()


def write_config(expected, replacement, stamp):
    # The helper sees no host filesystem except /etc/caddy, no network, and no
    # Docker socket. It atomically changes only Caddyfile after checking its hash.
    helper = r'''
const fs = require('node:fs');
const crypto = require('node:crypto');
let input = '';
process.stdin.on('data', b => { input += b; });
process.stdin.on('end', () => {
  const {expected, replacement, stamp} = JSON.parse(input);
  if (!/^[a-f0-9]{64}$/.test(expected) || !/^[0-9TZ-]+$/.test(stamp)) throw Error('Invalid input');
  const target = '/caddy/Caddyfile';
  const original = fs.readFileSync(target);
  const hash = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
  if (hash(original) !== expected) throw Error('Concurrent Caddyfile change; aborting');
  fs.writeFileSync(`/caddy/Caddyfile.before-mymemory-${stamp}`, original, {mode:0o600, flag:'wx'});
  const temporary = `/caddy/.Caddyfile.mymemory-${stamp}`;
  try {
    fs.writeFileSync(temporary, replacement, {mode:0o644, flag:'wx'});
    if (hash(fs.readFileSync(target)) !== expected) throw Error('Concurrent Caddyfile change; aborting');
    fs.renameSync(temporary, target);
  } finally {
    try { fs.unlinkSync(temporary); } catch (e) { if(e.code !== 'ENOENT') throw e; }
  }
});
'''
    payload = {'expected': expected, 'replacement': replacement, 'stamp': stamp}
    subprocess.run([
        'docker', 'run', '--rm', '-i', '--network', 'none', '--read-only',
        '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges:true',
        '--memory', '96m', '--pids-limit', '30',
        '--mount', 'type=bind,src=/etc/caddy,dst=/caddy', IMAGE,
        'node', '-e', helper,
    ], input=json.dumps(payload), text=True, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    original = CONFIG.read_text()
    route = Path(__file__).with_name('Caddyfile').read_text().strip()
    if original.count(BEGIN) != original.count(END) or original.count(BEGIN) > 1:
        raise SystemExit('Ambiguous MyMemory markers; no change made.')
    if BEGIN in original:
        before, rest = original.split(BEGIN, 1)
        _, after = rest.split(END, 1)
        candidate = before + route + after
    else:
        if any(domain in original for domain in ('mymemory.sommomi.cc', 'sommomemory.sommomi.cc')):
            raise SystemExit('An unmarked MyMemory route already exists; no change made.')
        candidate = original.rstrip() + '\n\n' + route + '\n'
    old_adapted = adapt(original)
    new_adapted = adapt(candidate)
    if active_config() != old_adapted:
        raise SystemExit('Runtime Caddy configuration differs from Caddyfile; inspect before changing it.')
    if candidate == original:
        print('MyMemory HTTPS route is already configured and active.')
        return
    print('Validated MyMemory route for 127.0.0.1:8798; all existing site blocks preserved.')
    if not args.apply:
        print('Read-only check complete. Use --apply to install and reload.')
        return
    with urllib.request.urlopen('http://127.0.0.1:8798/healthz', timeout=5) as response:
        if response.status != 200:
            raise SystemExit('MyMemory backend is not healthy; no change made.')
    if active_config() != old_adapted:
        raise SystemExit('Runtime Caddy configuration changed; no change made.')
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    digest = hashlib.sha256(original.encode()).hexdigest()
    write_config(digest, candidate, stamp)
    try:
        load_config(new_adapted)
    except Exception:
        # Only restore our exact candidate: never overwrite a subsequent edit.
        expected = hashlib.sha256(candidate.encode()).hexdigest()
        write_config(expected, original, stamp + '-1')
        load_config(old_adapted)
        raise
    print('MyMemory HTTPS route installed persistently and active; private Caddyfile backup retained.')


if __name__ == '__main__':
    main()
