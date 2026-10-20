"""Bootstrap registry credentials inside Kubernetes; never export their values."""

import base64
import http.cookiejar
import json
import os
from pathlib import Path
import secrets
import ssl
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, build_opener, HTTPCookieProcessor, HTTPSHandler


class APIError(Exception):
    def __init__(self, status):
        self.status = status
        super().__init__(f"API returned HTTP {status}; response suppressed")


class API:
    def __init__(self, base, headers=None, context=None):
        self.base = base
        self.headers = headers or {}
        self.csrf = None
        self.opener = build_opener(HTTPCookieProcessor(http.cookiejar.CookieJar()),
                                  HTTPSHandler(context=context))

    def call(self, path, method="GET", body=None):
        headers = dict(self.headers, **{"Content-Type": "application/json"})
        if self.csrf:
            headers["X-Harbor-CSRF-Token"] = self.csrf
        request = Request(self.base + path, method=method, headers=headers,
                          data=None if body is None else json.dumps(body).encode())
        try:
            with self.opener.open(request, timeout=30) as response:
                self.csrf = response.headers.get("X-Harbor-CSRF-Token", self.csrf)
                data = response.read()
                return json.loads(data) if data else None
        except HTTPError as error:
            raise APIError(error.code) from None


def basic(user, password):
    return "Basic " + base64.b64encode(f"{user}:{password}".encode()).decode()


class Bootstrap:
    def __init__(self, kube, harbor, harbor_url, registry, project, duration):
        self.kube, self.harbor = kube, harbor
        self.harbor_url, self.registry = harbor_url, registry
        self.project, self.duration = project, duration
        self.path = "/api/v1/namespaces/cicd-build/secrets/harbor-docker-config"

    def existing(self):
        try:
            return self.kube.call(self.path)
        except APIError as error:
            if error.status == 404:
                return None
            raise

    def valid(self, secret):
        try:
            expiry = secret.get("metadata", {}).get("annotations", {}).get(
                "ci.tencentcloud-k8s/harbor-robot-expires-at")
            if expiry and int(expiry) > 0 and int(expiry) <= time.time() + 86400:
                return False
            config = json.loads(base64.b64decode(secret["data"][".dockerconfigjson"]))
            auth = config["auths"][self.registry]["auth"]
            query = urlencode({"service": "harbor-registry",
                               "scope": f"repository:{self.project}/jenkins-bootstrap-check:pull,push"})
            client = API(self.harbor_url, {"Authorization": "Basic " + auth,
                                           "Host": self.registry})
            token = client.call("/service/token?" + query)["token"]
            payload = token.split(".")[1]
            claims = json.loads(base64.urlsafe_b64decode(payload + "=" * (-len(payload) % 4)))
            return any(item.get("type") == "repository"
                       and item.get("name") == f"{self.project}/jenkins-bootstrap-check"
                       and {"pull", "push"} <= set(item.get("actions", []))
                       for item in claims.get("access", []))
        except APIError as error:
            if error.status in (401, 403):
                return False
            raise
        except (KeyError, ValueError, TypeError, IndexError):
            return False

    def run(self):
        old = self.existing()
        if old and self.valid(old):
            print("Existing registry Secret verified; credentials retained", flush=True)
            return
        try:
            self.harbor.call("/api/v2.0/projects/" + self.project)
        except APIError as error:
            if error.status != 404:
                raise
            self.harbor.call("/api/v2.0/projects", "POST", {"project_name": self.project, "public": False})
        robot = self.harbor.call("/api/v2.0/robots", "POST", {
            "name": "jenkins-build-" + secrets.token_hex(6), "level": "project",
            "description": "Kubernetes Jenkins bootstrap; repository pull/push only",
            "duration": self.duration, "disable": False,
            "permissions": [{"kind": "project", "namespace": self.project,
                             "access": [{"resource": "repository", "action": action}
                                        for action in ("pull", "push")]}]})
        try:
            auth = base64.b64encode(f"{robot['name']}:{robot['secret']}".encode()).decode()
            config = {"auths": {self.registry: {"auth": auth}}}
            metadata = dict(old["metadata"]) if old else {"name": "harbor-docker-config", "namespace": "cicd-build"}
            metadata.setdefault("annotations", {}).update({
                "ci.tencentcloud-k8s/harbor-robot-id": str(robot["id"]),
                "ci.tencentcloud-k8s/harbor-robot-expires-at": str(robot["expires_at"])})
            metadata.setdefault("labels", {})["app.kubernetes.io/managed-by"] = "jenkins-harbor-bootstrap"
            secret = {"apiVersion": "v1", "kind": "Secret", "metadata": metadata,
                      "type": "kubernetes.io/dockerconfigjson",
                      "data": {".dockerconfigjson": base64.b64encode(json.dumps(config).encode()).decode()}}
            if not self.valid(secret):
                raise RuntimeError("New robot did not receive repository pull/push permission")
            self.kube.call(self.path if old else self.path.rsplit("/", 1)[0],
                           "PUT" if old else "POST", secret)
        except Exception:
            # Only remove the unused account just created by this attempt.
            self.harbor.call(f"/api/v2.0/robots/{robot['id']}", "DELETE")
            raise
        print("Registry Secret provisioned and pull/push permission verified", flush=True)


def main():
    service = Path("/var/run/secrets/kubernetes.io/serviceaccount")
    kube = API("https://kubernetes.default.svc", {"Authorization": "Bearer " + (service / "token").read_text()},
               ssl.create_default_context(cafile=str(service / "ca.crt")))
    url, registry = os.environ["HARBOR_URL"], os.environ["REGISTRY_HOST"]
    harbor = API(url, {"Authorization": basic("admin", os.environ["HARBOR_ADMIN_PASSWORD"]), "Host": registry})
    bootstrap = Bootstrap(kube, harbor, url, registry, os.environ["HARBOR_PROJECT"],
                          int(os.environ["ROBOT_DURATION_DAYS"]))
    for attempt in range(12):
        try:
            bootstrap.run()
            return
        except (APIError, URLError, TimeoutError, OSError) as error:
            print(f"Bootstrap attempt {attempt + 1} failed ({type(error).__name__}); details suppressed", flush=True)
            if attempt == 11:
                raise RuntimeError("Registry bootstrap failed; inspect service readiness and RBAC") from None
            time.sleep(5)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        print("Registry bootstrap failed; credential-bearing details suppressed", file=sys.stderr)
        sys.exit(1)
