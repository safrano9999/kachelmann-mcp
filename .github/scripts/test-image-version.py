#!/usr/bin/env python3
# Source of truth: SCRIPTS/githubactions. Generated copies are overwritten.
"""Exercise the workflow's allocator with occupied and explicit image tags."""
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[1] / "workflows/container-image.yml"
STEP = WORKFLOW.read_text().split("      - name: Resolve application and image versions\n", 1)[1]
SCRIPT = textwrap.dedent(STEP.split("        run: |\n", 1)[1].split("\n      - name:", 1)[0])


class ImageVersionTests(unittest.TestCase):
    def allocate(self, requested="", tags="latest\n2026.10.5\n2026.10.12\n2026.9.99\n"):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "source").mkdir()
            (root / "source/release.json").write_text('{"version":"2026.10.5"}\n')
            for name, source in {
                "gh": '#!/bin/sh\nprintf "%s" "$TEST_TAGS"\n',
                "date": '#!/bin/sh\nprintf "2026.10\\n"\n',
            }.items():
                executable = root / name
                executable.write_text(source)
                executable.chmod(0o755)
            output = root / "output"
            result = subprocess.run(
                ["bash", "-c", SCRIPT], cwd=root, capture_output=True, text=True,
                env={**os.environ, "PATH": temporary + os.pathsep + os.environ["PATH"],
                     "IMAGE_TAG": requested, "TEST_TAGS": tags,
                     "IMAGE_NAME": "ghcr.io/safrano9999/kachelmann-mcp",
                     "GITHUB_OUTPUT": str(output)},
            )
            return result, output.read_text() if output.exists() else ""

    def test_automatic_image_number_is_independent_of_application_version(self):
        result, output = self.allocate()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("version=2026.10.13\n", output)
        self.assertIn("app_version=2026.10.5\n", output)

    def test_explicit_occupied_image_is_rejected(self):
        result, output = self.allocate("2026.10.5")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Refusing to overwrite", result.stderr)
        self.assertEqual(output, "")

    def test_explicit_unused_image_is_preserved(self):
        result, output = self.allocate("2026.10.20")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("version=2026.10.20\n", output)

    def test_first_image_in_month(self):
        result, output = self.allocate(tags="latest\n2026.9.99\n")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("version=2026.10.1\n", output)


if __name__ == "__main__":
    unittest.main()
