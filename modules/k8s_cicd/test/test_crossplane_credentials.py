"""Exercise actual credential encoding, enablement and lifecycle preconditions offline."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


@unittest.skipUnless(shutil.which("terraform"), "Terraform CLI is required")
class CrossplaneCredentialsTests(unittest.TestCase):
    def test_credentials_and_enablement(self):
        module = Path(__file__).resolve().parents[1]
        source = (module / "crossplane_credentials.tf").read_text()
        variables = (module / "variables.tf").read_text()
        declarations = []
        for name in ("secret_id", "secret_key", "crossplane_region"):
            declaration = 'variable "' + name + '" {'
            declarations.append(declaration + variables.split(declaration, 1)[1].split('\nvariable ', 1)[0])
        # Use Terraform's built-in resource so no cluster, credentials or external
        # provider is needed. The locals, count and lifecycle expressions are
        # taken from the production configuration rather than reimplemented.
        locals_source = source.split('resource "kubernetes_secret_v1"', 1)[0]
        count = source.split("  count = ", 1)[1].split("\n", 1)[0]
        lifecycle = source.split("  lifecycle {", 1)[1].rsplit("}", 1)[0]
        fixture = '\n'.join(declarations) + '''
variable "enabled_component_names" { type = set(string) }
locals { enabled_component_names = var.enabled_component_names }
''' + locals_source + '\nresource "terraform_data" "credentials" {\n' + \
            'count = ' + count + '\ninput = local.crossplane_tencentcloud_credentials\n' + \
            'lifecycle {' + lifecycle + '\n}\n'
        env = {key: value for key, value in os.environ.items() if not key.startswith("TF_VAR_")}
        with tempfile.TemporaryDirectory(prefix="crossplane-credentials-") as directory:
            root = Path(directory)
            (root / "main.tf").write_text(fixture)

            def run(*args):
                return subprocess.run(
                    ["terraform", f"-chdir={root}", *args], env=env,
                    capture_output=True, text=True, timeout=30,
                )

            initialized = run("init", "-backend=false", "-input=false", "-no-color")
            self.assertEqual(initialized.returncode, 0, initialized.stderr)
            cases = [
                (False, "", "", True),
                (True, "", "fixture-key", False),
                (True, "fixture-id", "", False),
                (True, "fixture id", "fixture-key", False),
                (True, "fixture-id", "\t", False),
                (True, "fixture-id", 'fixture-"key\\value', True),
            ]
            for enabled, secret_id, secret_key, valid in cases:
                with self.subTest(enabled=enabled, valid=valid):
                    (root / "case.tfvars.json").write_text(json.dumps({
                        "enabled_component_names": ["crossplane"] if enabled else [],
                        "secret_id": secret_id, "secret_key": secret_key,
                        "crossplane_region": "ap-guangzhou",
                    }))
                    result = run("plan", "-input=false", "-no-color", "-var-file=case.tfvars.json", "-out=fixture.plan")
                    if not valid:
                        self.assertNotEqual(result.returncode, 0)
                        self.assertIn("Crossplane requires nonempty", result.stderr)
                        continue
                    self.assertEqual(result.returncode, 0, result.stderr)
                    shown = run("show", "-json", "fixture.plan")
                    self.assertEqual(shown.returncode, 0, shown.stderr)
                    resources = json.loads(shown.stdout)["planned_values"]["root_module"].get("resources", [])
                    self.assertEqual(len(resources), int(enabled))
                    if enabled:
                        credentials = json.loads(resources[0]["values"]["input"])
                        self.assertEqual(credentials, {"secret_id": secret_id, "secret_key": secret_key, "region": "ap-guangzhou"})


if __name__ == "__main__":
    unittest.main()
