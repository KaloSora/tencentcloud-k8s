"""In-cluster application pull credential reconciliation, invoked by Terraform's chart."""

import base64
import json
import os
from pathlib import Path
import secrets
import ssl
import sys
import time
from urllib.error import URLError
from urllib.parse import urlencode

from harbor_registry_auth import API, APIError, basic


class ApplicationPullAuth:
    def __init__(self, kube, harbor, url, registry, project, duration):
        self.kube, self.harbor = kube, harbor
        self.url, self.registry, self.project, self.duration = url, registry, project, duration

    def valid(self, secret):
        try:
            annotations = secret.get('metadata', {}).get('annotations', {})
            expiry = int(annotations['ci.tencentcloud-k8s/harbor-robot-expires-at'])
            if expiry <= time.time() + 7 * 86400:
                return False
            robot = self.harbor.call('/api/v2.0/robots/' + str(int(annotations['ci.tencentcloud-k8s/harbor-robot-id'])))
            if robot.get('disable') or robot.get('level') != 'project':
                return False
            if int(robot.get('expires_at', 0)) <= time.time() + 7 * 86400:
                return False
            permissions = robot.get('permissions', [])
            if len(permissions) != 1 or permissions[0].get('namespace') != self.project:
                return False
            access = permissions[0].get('access', [])
            if not access or any(item.get('resource') != 'repository' or item.get('action') != 'pull'
                                 for item in access):
                return False
            config = json.loads(base64.b64decode(secret['data']['.dockerconfigjson']))
            auth = config['auths'][self.registry]['auth']
            # Request both actions so a build credential cannot masquerade as pull-only.
            query = urlencode({'service': 'harbor-registry',
                               'scope': 'repository:' + self.project + '/app-pull-check:pull,push'})
            client = API(self.url, {'Authorization': 'Basic ' + auth, 'Host': self.registry})
            token = client.call('/service/token?' + query)['token']
            payload = token.split('.')[1]
            claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
            return any(item.get('name') == self.project + '/app-pull-check'
                       and item.get('type') == 'repository' and set(item.get('actions', [])) == {'pull'}
                       for item in claims.get('access', []))
        except APIError as error:
            if error.status in (401, 403, 404):
                return False
            raise
        except (KeyError, ValueError, TypeError, IndexError):
            return False

    def reconcile(self, namespace):
        path = '/api/v1/namespaces/' + namespace + '/secrets/harbor-docker-config'
        try:
            old = self.kube.call(path)
        except APIError as error:
            if error.status != 404:
                raise
            old = None
        if old and self.valid(old):
            labels = old['metadata'].setdefault('labels', {})
            if labels.get('app.kubernetes.io/managed-by') != 'terraform-harbor-app-pull':
                labels['app.kubernetes.io/managed-by'] = 'terraform-harbor-app-pull'
                self.kube.call(path, 'PUT', old)
            print(namespace + ': existing pull-only credentials verified and retained', flush=True)
            return
        robot = self.harbor.call('/api/v2.0/robots', 'POST', {
            'name': 'app-pull-' + namespace + '-' + secrets.token_hex(6), 'level': 'project',
            'description': 'Terraform-managed application pull credentials for ' + namespace,
            'duration': self.duration, 'disable': False,
            'permissions': [{'kind': 'project', 'namespace': self.project,
                             'access': [{'resource': 'repository', 'action': 'pull'}]}]})
        try:
            auth = base64.b64encode((robot['name'] + ':' + robot['secret']).encode()).decode()
            config = {'auths': {self.registry: {'auth': auth}}}
            metadata = dict(old['metadata']) if old else {'name': 'harbor-docker-config', 'namespace': namespace}
            metadata.setdefault('annotations', {}).update({
                'ci.tencentcloud-k8s/harbor-robot-id': str(robot['id']),
                'ci.tencentcloud-k8s/harbor-robot-expires-at': str(robot['expires_at'])})
            metadata.setdefault('labels', {})['app.kubernetes.io/managed-by'] = 'terraform-harbor-app-pull'
            secret = {'apiVersion': 'v1', 'kind': 'Secret', 'metadata': metadata,
                      'type': 'kubernetes.io/dockerconfigjson',
                      'data': {'.dockerconfigjson': base64.b64encode(json.dumps(config).encode()).decode()}}
            if not self.valid(secret):
                raise RuntimeError('New robot did not receive only repository pull permission')
            self.kube.call(path if old else path.rsplit('/', 1)[0], 'PUT' if old else 'POST', secret)
        except Exception:
            # The failed write might have reached Kubernetes before a connection
            # error. Keep the robot in that case so existing Pods retain access.
            try:
                current = self.kube.call(path)
                installed = current.get('metadata', {}).get('annotations', {}).get(
                    'ci.tencentcloud-k8s/harbor-robot-id') == str(robot['id'])
            except APIError as error:
                if error.status != 404:
                    raise
                installed = False
            if not installed:
                self.harbor.call('/api/v2.0/robots/' + str(robot['id']), 'DELETE')
            raise
        print(namespace + ': pull-only credentials reconciled', flush=True)


def main():
    service = Path('/var/run/secrets/kubernetes.io/serviceaccount')
    kube = API('https://kubernetes.default.svc', {'Authorization': 'Bearer ' + (service / 'token').read_text()},
               ssl.create_default_context(cafile=str(service / 'ca.crt')))
    url, registry = os.environ['HARBOR_URL'], os.environ['REGISTRY_HOST']
    harbor = API(url, {'Authorization': basic('admin', os.environ['HARBOR_ADMIN_PASSWORD']), 'Host': registry})
    auth = ApplicationPullAuth(kube, harbor, url, registry, os.environ['HARBOR_PROJECT'],
                               int(os.environ['ROBOT_DURATION_DAYS']))
    try:
        harbor.call('/api/v2.0/projects/' + auth.project)
    except APIError as error:
        if error.status != 404:
            raise
        try:
            harbor.call('/api/v2.0/projects', 'POST', {'project_name': auth.project, 'public': False})
        except APIError as conflict:
            # The Jenkins bootstrap may have created the same project concurrently.
            if conflict.status != 409:
                raise
    for namespace in json.loads(os.environ['APPLICATION_NAMESPACES']):
        for attempt in range(12):
            try:
                auth.reconcile(namespace)
                break
            except (APIError, URLError, TimeoutError, OSError) as error:
                reason = 'HTTP ' + str(error.status) if isinstance(error, APIError) else type(error).__name__
                print(namespace + ': reconciliation failed (' + reason + '); credential-bearing details suppressed', flush=True)
                if attempt == 11:
                    raise
                time.sleep(5)


if __name__ == '__main__':
    try:
        main()
    except Exception:
        print('Application pull bootstrap failed; credential-bearing details suppressed', file=sys.stderr)
        sys.exit(1)
