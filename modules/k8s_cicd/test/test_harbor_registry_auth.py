from pathlib import Path
import io
import sys
import unittest
from unittest.mock import Mock, patch
from urllib.error import HTTPError

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "script"))
from harbor_registry_auth import API, APIError, Bootstrap


class APITests(unittest.TestCase):
    def test_csrf_challenge_retries_once_with_response_token(self):
        api = API('http://harbor-core')
        challenge = HTTPError('http://harbor-core', 403, 'Forbidden',
                              {'X-Harbor-CSRF-Token': 'csrf-fixture'}, None)
        response = io.BytesIO(b'{"id": 1}')
        response.headers = {}
        api.opener = Mock()
        api.opener.open.side_effect = [challenge, response]
        self.assertEqual(api.call('/api/v2.0/robots', 'POST', {}), {'id': 1})
        request = api.opener.open.call_args_list[1].args[0]
        self.assertEqual(request.get_header('X-harbor-csrf-token'), 'csrf-fixture')
        self.assertEqual(request.get_method(), 'POST')

    def test_repeated_csrf_challenge_does_not_retry_forever(self):
        api = API('http://harbor-core')
        api.opener = Mock()
        api.opener.open.side_effect = HTTPError('http://harbor-core', 403, 'Forbidden',
                                               {'X-Harbor-CSRF-Token': 'csrf-fixture'}, None)
        with self.assertRaises(APIError):
            api.call('/api/v2.0/robots', 'POST', {})
        self.assertEqual(api.opener.open.call_count, 2)

    def test_ordinary_forbidden_is_not_retried(self):
        api = API('http://harbor-core')
        api.opener = Mock()
        api.opener.open.side_effect = HTTPError('http://harbor-core', 403, 'Forbidden', {}, None)
        with self.assertRaises(APIError):
            api.call('/api/v2.0/robots', 'POST', {})
        self.assertEqual(api.opener.open.call_count, 1)


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
