"""Exercise the root and child module's actual token variable declarations."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


@unittest.skipUnless(shutil.which("terraform"), "Terraform CLI is required")
class GitOpsTokenValidationTests(unittest.TestCase):
    def test_required_nonempty_token(self):
        module = Path(__file__).resolve().parents[1]
        env = {key: value for key, value in os.environ.items()
               if not key.startswith("TF_VAR_")}
        for source in (module.parent / "variables.tf", module / "variables.tf"):
            declaration = source.read_text().split('variable "gitops_github_token" {', 1)[1]
            declaration = 'variable "gitops_github_token" {' + declaration.split('\nvariable ', 1)[0]
            with tempfile.TemporaryDirectory(prefix="gitops-token-validation-") as directory:
                root = Path(directory)
                (root / "main.tf").write_text(declaration)

                def run(*args):
                    return subprocess.run(
                        ["terraform", f"-chdir={root}", *args], env=env,
                        capture_output=True, text=True, timeout=30)

                initialized = run("init", "-backend=false", "-input=false", "-no-color")
                self.assertEqual(initialized.returncode, 0, initialized.stderr)
                for token in ("", " ", "\t\n", "token with spaces", None, "fixture-token"):
                    with self.subTest(source=source, token=token):
                        (root / "case.tfvars.json").write_text(json.dumps({"gitops_github_token": token}))
                        result = run("plan", "-input=false", "-no-color", "-var-file=case.tfvars.json")
                        if token == "fixture-token":
                            self.assertEqual(result.returncode, 0, result.stderr)
                        else:
                            self.assertNotEqual(result.returncode, 0)
                            self.assertIn("gitops_github_token", result.stderr)
                missing = run("plan", "-input=false", "-no-color")
                self.assertNotEqual(missing.returncode, 0)
                self.assertIn("No value for required variable", missing.stderr)


if __name__ == "__main__":
    unittest.main()
