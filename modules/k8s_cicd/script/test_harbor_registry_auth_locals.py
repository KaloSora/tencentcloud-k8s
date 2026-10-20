"""Evaluate real bootstrap locals without providers, backend, or cluster access."""

import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


@unittest.skipUnless(shutil.which("terraform"), "Terraform CLI is required")
class BootstrapLocalsTests(unittest.TestCase):
    def test_optional_config_and_disabled_components(self):
        module = Path(__file__).resolve().parents[1]
        source = (module / "harbor_registry_auth.tf").read_text()
        locals_block = source[:source.index("\n}\n") + 3]
        prefix = '''locals {
  enabled_component_names = nonsensitive(toset([
    for name, component in var.components : name if component.enabled
  ]))
  jenkins_enabled = contains(local.enabled_component_names, "jenkins")
}
'''
        output = '''output "settings" {
  value = {
    enabled = local.harbor_auth_enabled
    project = local.harbor_auth_project
    duration = local.harbor_auth_duration
    revision = local.harbor_auth_revision
    registry = local.harbor_auth_registry
    release = local.harbor_auth_release
    namespace = local.harbor_auth_namespace
  }
}
'''

        def component(name, **config):
            return dict(enabled=True, release_name=name, namespace=name,
                        repository="https://example.invalid", chart=name, version="1.0.0",
                        timeout=60, atomic=True, wait=True, wait_for_jobs=False,
                        value_templates=[], config=config)

        defaults = dict(project="library", duration="90", revision="1",
                        registry="harbor.core.com", release="harbor", namespace="harbor")
        custom = dict(project="custom", duration="30", revision="2",
                      registry="registry.example.test", release="registry", namespace="registry")
        cases = [
            ({"jenkins": component("jenkins"), "harbor": component("harbor")}, defaults, True),
            ({"jenkins": component("jenkins", jenkins_harbor_project="custom",
                                   jenkins_harbor_robot_duration_days="30", jenkins_harbor_bootstrap_revision="2"),
              "harbor": component("registry", harbor_url="registry.example.test")}, custom, True),
            ({"harbor": component("harbor")}, defaults, False),
            ({"jenkins": component("jenkins")}, defaults, False),
            ({}, defaults, False),
        ]
        with tempfile.TemporaryDirectory(prefix="harbor-auth-locals-") as directory:
            root = Path(directory)
            (root / "script").mkdir()
            shutil.copyfile(module / "script/harbor_registry_auth.py", root / "script/harbor_registry_auth.py")
            (root / "variables.tf").write_text((module / "variables.tf").read_text())
            (root / "main.tf").write_text(prefix + locals_block + output)

            def run(*args):
                result = subprocess.run(["terraform", f"-chdir={root}", *args],
                                        capture_output=True, text=True, timeout=30)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                return result.stdout

            run("init", "-backend=false", "-input=false", "-no-color")
            for components, expected, enabled in cases:
                with self.subTest(components=list(components)):
                    (root / "case.tfvars.json").write_text(json.dumps({
                        "components": components, "storage_class_name": "test", "k8s_version": "1.28.3"}))
                    run("plan", "-input=false", "-no-color", "-var-file=case.tfvars.json", "-out=case.tfplan")
                    plan = json.loads(run("show", "-json", "case.tfplan"))
                    self.assertEqual(plan["planned_values"]["outputs"]["settings"]["value"],
                                     dict(expected, enabled=enabled))


if __name__ == "__main__":
    unittest.main()
