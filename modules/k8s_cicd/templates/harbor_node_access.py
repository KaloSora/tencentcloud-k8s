"""Terraform node provisioner payload: preserve configuration, validate and reload Docker."""

import argparse
from datetime import datetime
import ipaddress
import json
from pathlib import Path
import re
import shutil
import socket
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--registry', required=True)
    parser.add_argument('--address', required=True)
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    ipaddress.ip_address(args.address)
    if not re.fullmatch(r'[a-z0-9]+(?:[.-][a-z0-9]+)*', args.registry):
        parser.error('registry must be a hostname without scheme, port or path')
    hosts_path = Path('/etc/hosts')
    daemon_path = Path('/etc/docker/daemon.json')
    hosts = hosts_path.read_text()
    lines = []
    for line in hosts.splitlines():
        fields = line.split('#', 1)[0].split()
        if len(fields) > 1 and args.registry in fields[1:]:
            aliases = [alias for alias in fields[1:] if alias != args.registry]
            if aliases:
                lines.append(fields[0] + '\t' + ' '.join(aliases))
        else:
            lines.append(line)
    new_hosts = '\n'.join(lines).rstrip() + '\n' + args.address + '\t' + args.registry + '\n'
    config = json.loads(daemon_path.read_text()) if daemon_path.exists() else {}
    registries = config.setdefault('insecure-registries', [])
    if args.registry not in registries:
        registries.append(args.registry)
    new_daemon = json.dumps(config, indent=2) + '\n'
    with tempfile.NamedTemporaryFile(mode='w', prefix='harbor-daemon-', suffix='.json') as candidate:
        candidate.write(new_daemon)
        candidate.flush()
        subprocess.run(['dockerd', '--validate', '--config-file', candidate.name], check=True)
    print('Validated: {} -> {}; allow HTTP registry {}'.format(args.registry, args.address, args.registry))
    if not args.apply:
        return
    timestamp = datetime.now().strftime('%Y%m%d%H%M%S%f')
    for path, value in ((hosts_path, new_hosts), (daemon_path, new_daemon)):
        if path.exists() and path.read_text() == value:
            continue
        if path.exists():
            backup = str(path) + '.before-harbor-' + timestamp
            shutil.copy2(str(path), backup)
            print('Backup: ' + backup)
        path.write_text(value)
    subprocess.run(['systemctl', 'reload', 'docker'], check=True)
    for _ in range(10):
        info = json.loads(subprocess.check_output(['docker', 'info', '--format', '{{json .RegistryConfig.IndexConfigs}}']))
        if info.get(args.registry, {}).get('Secure') is False:
            break
        time.sleep(1)
    else:
        raise RuntimeError('Docker did not activate the HTTP registry setting; inspect daemon logs')
    if socket.gethostbyname(args.registry) != args.address:
        raise RuntimeError('Host resolver does not return expected Harbor address')
    status = subprocess.check_output([
        'curl', '--noproxy', '*', '--silent', '--show-error', '--output', '/dev/null',
        '--write-out', '%{http_code}', '--max-time', '15', 'http://' + args.registry + '/v2/']).decode()
    if status not in ('200', '401'):
        raise RuntimeError('Unexpected Harbor /v2/ HTTP status: ' + status)
    print('Harbor /v2/ HTTP status: ' + status)
    print('Node DNS and Docker HTTP registry verified')


if __name__ == '__main__':
    main()
