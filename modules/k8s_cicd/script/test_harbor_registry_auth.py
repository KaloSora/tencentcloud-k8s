import unittest
from unittest.mock import patch

from harbor_registry_auth import APIError, Bootstrap


class FakeAPI:
    def __init__(self, old=None, fail_write=False):
        self.old, self.fail_write = old, fail_write
        self.calls = []

    def call(self, path, method="GET", body=None):
        self.calls.append((path, method, body))
        if path.startswith('/api/v1/'):
            if method == 'GET':
                if self.old is None:
                    raise APIError(404)
                return self.old
            if self.fail_write:
                raise APIError(403)
            return body
        if path == '/api/v2.0/robots' and method == 'POST':
            return {'name': 'robot$library+test', 'secret': 'unit-test-value', 'id': 2, 'expires_at': 2000000000}
        return {}


class BootstrapTests(unittest.TestCase):
    def make(self, old=None, fail_write=False):
        kube, harbor = FakeAPI(old, fail_write), FakeAPI()
        return Bootstrap(kube, harbor, 'http://harbor-core', 'harbor.core.com', 'library', 90), kube, harbor

    def test_valid_existing_secret_does_not_create_or_rotate_robot(self):
        bootstrap, kube, harbor = self.make({'metadata': {}})
        with patch.object(bootstrap, 'valid', return_value=True):
            bootstrap.run()
        self.assertEqual(harbor.calls, [])
        self.assertEqual(len(kube.calls), 1)

    def test_missing_secret_creates_project_scoped_robot_then_secret(self):
        bootstrap, kube, harbor = self.make()
        with patch.object(bootstrap, 'valid', return_value=True):
            bootstrap.run()
        robot = next(body for path, method, body in harbor.calls if path == '/api/v2.0/robots')
        self.assertEqual(robot['level'], 'project')
        self.assertEqual(robot['permissions'], [{'kind': 'project', 'namespace': 'library', 'access': [
            {'resource': 'repository', 'action': 'pull'}, {'resource': 'repository', 'action': 'push'}]}])
        self.assertEqual(kube.calls[-1][1], 'POST')
        self.assertEqual(kube.calls[-1][2]['type'], 'kubernetes.io/dockerconfigjson')

    def test_expired_secret_is_updated_with_resource_version(self):
        bootstrap, kube, harbor = self.make({'metadata': {'resourceVersion': '7'}})
        with patch.object(bootstrap, 'valid', side_effect=[False, True]):
            bootstrap.run()
        self.assertEqual(kube.calls[-1][1], 'PUT')
        self.assertEqual(kube.calls[-1][2]['metadata']['resourceVersion'], '7')

    def test_write_failure_removes_only_unused_new_robot(self):
        bootstrap, kube, harbor = self.make(fail_write=True)
        with patch.object(bootstrap, 'valid', return_value=True):
            with self.assertRaises(APIError):
                bootstrap.run()
        self.assertEqual(harbor.calls[-1][:2], ('/api/v2.0/robots/2', 'DELETE'))

    def test_permission_failure_does_not_publish_invalid_secret(self):
        bootstrap, kube, harbor = self.make()
        with patch.object(bootstrap, 'valid', return_value=False):
            with self.assertRaises(RuntimeError):
                bootstrap.run()
        self.assertEqual(len(kube.calls), 1)
        self.assertEqual(harbor.calls[-1][:2], ('/api/v2.0/robots/2', 'DELETE'))


if __name__ == '__main__':
    unittest.main()
