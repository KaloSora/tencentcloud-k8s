import base64
import json
from pathlib import Path
import sys
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'script'))
from application_pull_auth import ApplicationPullAuth
from harbor_registry_auth import APIError


class FakeAPI:
    def __init__(self):
        self.calls = []
        self.secret = None
        self.robot = {'id': 2, 'name': 'robot$library+fixture', 'secret': 'fixture-value',
                      'expires_at': int(time.time()) + 90 * 86400, 'disable': False, 'level': 'project',
                      'permissions': [{'kind': 'project', 'namespace': 'library',
                                       'access': [{'resource': 'repository', 'action': 'pull'}]}]}
        self.fail_write = False

    def call(self, path, method='GET', body=None):
        self.calls.append((path, method, body))
        if path.startswith('/api/v1/'):
            if method == 'GET':
                if self.secret is None:
                    raise APIError(404)
                return self.secret
            if self.fail_write:
                raise APIError(403)
            self.secret = body
            return body
        return self.robot


class ApplicationPullAuthTests(unittest.TestCase):
    def setUp(self):
        self.kube, self.harbor = FakeAPI(), FakeAPI()
        self.auth = ApplicationPullAuth(self.kube, self.harbor, 'http://harbor-core',
                                        'harbor.core.com', 'library', 90)

    def secret(self):
        return {'metadata': {'resourceVersion': '7', 'annotations': {
            'ci.tencentcloud-k8s/harbor-robot-id': '2',
            'ci.tencentcloud-k8s/harbor-robot-expires-at': str(int(time.time()) + 90 * 86400)}},
            'data': {'.dockerconfigjson': base64.b64encode(json.dumps({
                'auths': {'harbor.core.com': {'auth': 'fixture'}}}).encode()).decode()}}

    def token_client(self, actions):
        payload = base64.urlsafe_b64encode(json.dumps({'access': [{
            'name': 'library/app-pull-check', 'type': 'repository', 'actions': actions}]}).encode()).decode().rstrip('=')
        client = unittest.mock.Mock()
        client.call.return_value = {'token': 'header.' + payload + '.signature'}
        return client

    def test_adopts_valid_existing_pull_only_secret_without_rotation(self):
        self.kube.secret = self.secret()
        with patch('application_pull_auth.API', return_value=self.token_client(['pull'])):
            self.auth.reconcile('dev')
        self.assertTrue(all(method == 'GET' for _, method, _ in self.harbor.calls))
        self.assertEqual(self.kube.calls[-1][1], 'PUT')
        self.assertEqual(self.kube.secret['metadata']['labels']['app.kubernetes.io/managed-by'],
                         'terraform-harbor-app-pull')
        self.assertEqual(self.kube.secret['data'], self.secret()['data'])

    def test_already_managed_valid_secret_is_a_noop(self):
        self.kube.secret = self.secret()
        self.kube.secret['metadata']['labels'] = {'app.kubernetes.io/managed-by': 'terraform-harbor-app-pull'}
        with patch('application_pull_auth.API', return_value=self.token_client(['pull'])):
            self.auth.reconcile('dev')
        self.assertTrue(all(method == 'GET' for _, method, _ in self.kube.calls))

    def test_missing_secret_creates_only_pull_permission_in_target_namespace(self):
        with patch('application_pull_auth.API', return_value=self.token_client(['pull'])):
            self.auth.reconcile('uat')
        robot = next(body for path, method, body in self.harbor.calls if method == 'POST')
        self.assertEqual(robot['permissions'][0]['access'], [{'resource': 'repository', 'action': 'pull'}])
        self.assertEqual(self.kube.calls[-1][0], '/api/v1/namespaces/uat/secrets')
        self.assertEqual(self.kube.secret['metadata']['namespace'], 'uat')

    def test_near_expiry_rotates_preserving_resource_version(self):
        self.kube.secret = self.secret()
        self.kube.secret['metadata']['annotations']['ci.tencentcloud-k8s/harbor-robot-expires-at'] = str(int(time.time()) + 86400)
        with patch('application_pull_auth.API', return_value=self.token_client(['pull'])):
            self.auth.reconcile('dev')
        self.assertEqual(self.kube.calls[-1][1], 'PUT')
        self.assertEqual(self.kube.secret['metadata']['resourceVersion'], '7')

    def test_rejects_robot_with_push_permission_or_disabled_robot(self):
        self.harbor.robot['permissions'][0]['access'].append({'resource': 'repository', 'action': 'push'})
        self.assertFalse(self.auth.valid(self.secret()))
        self.harbor.robot['permissions'][0]['access'].pop()
        self.harbor.robot['disable'] = True
        self.assertFalse(self.auth.valid(self.secret()))

    def test_rejects_token_with_push_grant(self):
        with patch('application_pull_auth.API', return_value=self.token_client(['pull', 'push'])):
            self.assertFalse(self.auth.valid(self.secret()))

    def test_failed_secret_write_deletes_only_unused_new_robot(self):
        self.kube.fail_write = True
        with patch('application_pull_auth.API', return_value=self.token_client(['pull'])):
            with self.assertRaises(APIError):
                self.auth.reconcile('dev')
        self.assertEqual(self.harbor.calls[-1][:2], ('/api/v2.0/robots/2', 'DELETE'))

    def test_expired_or_malformed_secret_is_invalid(self):
        self.assertFalse(self.auth.valid({}))
        secret = self.secret()
        secret['metadata']['annotations']['ci.tencentcloud-k8s/harbor-robot-expires-at'] = '1'
        self.assertFalse(self.auth.valid(secret))

    def test_actual_robot_expiry_overrides_stale_secret_annotation(self):
        self.harbor.robot['expires_at'] = int(time.time()) + 86400
        self.assertFalse(self.auth.valid(self.secret()))


if __name__ == '__main__':
    unittest.main()
