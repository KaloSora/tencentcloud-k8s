import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    'harbor_node_access', Path(__file__).resolve().parents[1] / 'templates/harbor_node_access.py')
node = importlib.util.module_from_spec(spec)
spec.loader.exec_module(node)


class NodeAccessTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.hosts = self.root / 'hosts'
        self.daemon = self.root / 'daemon.json'
        self.hosts.write_text('127.0.0.1 localhost\n192.0.2.1 harbor.core.com another.internal\n')
        self.daemon.write_text(json.dumps({'log-driver': 'json-file', 'insecure-registries': ['other.internal']}))

    def invoke(self, apply=False, validate_error=None):
        args = ['provisioner', '--registry', 'harbor.core.com', '--address', '10.99.21.232']
        if apply:
            args.append('--apply')
        with patch.object(sys, 'argv', args), patch.object(node, 'Path', side_effect=lambda path: {
                '/etc/hosts': self.hosts, '/etc/docker/daemon.json': self.daemon}[path]), \
                patch.object(node.subprocess, 'run', side_effect=validate_error) as run, \
                patch.object(node.subprocess, 'check_output', side_effect=[
                    b'{"harbor.core.com":{"Secure":false}}', b'401']), \
                patch.object(node.socket, 'gethostbyname', return_value='10.99.21.232'):
            node.main()
            return run

    def test_apply_preserves_other_hosts_and_docker_settings_and_is_idempotent(self):
        run = self.invoke(apply=True)
        self.assertIn('192.0.2.1\tanother.internal', self.hosts.read_text())
        self.assertIn('127.0.0.1 localhost', self.hosts.read_text())
        self.assertEqual(self.hosts.read_text().count('harbor.core.com'), 1)
        config = json.loads(self.daemon.read_text())
        self.assertEqual(config['log-driver'], 'json-file')
        self.assertEqual(config['insecure-registries'], ['other.internal', 'harbor.core.com'])
        self.assertEqual(run.call_args_list[-1].args[0], ['systemctl', 'reload', 'docker'])
        backups = list(self.root.glob('*.before-harbor-*'))
        self.assertEqual(len(backups), 2)
        first_hosts, first_daemon = self.hosts.read_text(), self.daemon.read_text()
        self.invoke(apply=True)
        self.assertEqual(self.hosts.read_text(), first_hosts)
        self.assertEqual(self.daemon.read_text(), first_daemon)
        self.assertEqual(len(list(self.root.glob('*.before-harbor-*'))), 2)

    def test_preview_does_not_write_or_reload(self):
        before = self.hosts.read_text(), self.daemon.read_text()
        run = self.invoke()
        self.assertEqual(before, (self.hosts.read_text(), self.daemon.read_text()))
        self.assertEqual(run.call_count, 1)

    def test_invalid_docker_candidate_leaves_existing_configuration_untouched(self):
        before = self.hosts.read_text(), self.daemon.read_text()
        with self.assertRaises(subprocess.CalledProcessError):
            self.invoke(apply=True, validate_error=subprocess.CalledProcessError(1, ['dockerd', '--validate']))
        self.assertEqual(before, (self.hosts.read_text(), self.daemon.read_text()))

    def test_terraform_executor_propagates_payload_failure(self):
        source = (Path(__file__).resolve().parents[1] / 'harbor_node_access.tf').read_text()
        block = re.search(r'inline = \[(.*?)\n    \]', source, re.S).group(1)
        commands = [json.loads(line.strip().rstrip(',')) for line in block.splitlines() if line.strip()]
        commands = [re.sub(r'\$\{[^}]+\}', 'fixture', command) for command in commands]
        # An actual failed payload must not be hidden by the successful cleanup.
        fake_python = self.root / 'python3'
        fake_python.write_text('#!/bin/sh\nexit 7\n')
        fake_python.chmod(0o700)
        commands[-1] = 'true'
        result = subprocess.run(['sh', '-c', '\n'.join(commands)],
                                env={**os.environ, 'PATH': str(self.root) + os.pathsep + os.environ['PATH']},
                                capture_output=True)
        self.assertEqual(result.returncode, 7)


if __name__ == '__main__':
    unittest.main()
