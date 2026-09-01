import os
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


class LaunchAgentScriptTests(unittest.TestCase):
    def test_installer_registers_one_persistent_user_agent(self):
        script = (ROOT / "scripts/install-fatcat-launch-agent.sh").read_text(encoding="utf-8")

        self.assertIn("com.fatcat.agent", script)
        self.assertIn("Library/LaunchAgents", script)
        self.assertIn("Library/Application Support/FatCat/runtime/fatcat-agent.sock", script)
        self.assertIn("Library/Application Support/FatCat/Hermes", script)
        self.assertIn("<key>RunAtLoad</key>", script)
        self.assertIn("<key>KeepAlive</key>", script)
        self.assertIn("launchctl bootstrap", script)
        self.assertIn("launchctl kickstart", script)
        self.assertIn("plutil -lint", script)

    def test_uninstaller_preserves_user_data_and_targets_only_fatcat(self):
        script = (ROOT / "scripts/uninstall-fatcat-launch-agent.sh").read_text(encoding="utf-8")

        self.assertIn("com.fatcat.agent", script)
        self.assertIn("launchctl bootout", script)
        self.assertNotIn("Application Support/FatCat/Hermes", script)
        self.assertNotIn("rm -rf", script)

    def test_native_build_registers_the_bundled_agent_before_opening(self):
        script = (ROOT / "scripts/run-peppa-macos.sh").read_text(encoding="utf-8")

        install = script.index('install-fatcat-launch-agent.sh')
        launch = script.index('open -a "$APP_BUNDLE"')
        self.assertLess(install, launch)
        self.assertIn('FATCAT_AGENT_PATH="$APP_BUNDLE/Contents/Resources/PeppaAgent/PeppaAgent"', script)

    def test_installer_retries_a_transient_launchd_bootstrap_race(self):
        with tempfile.TemporaryDirectory() as root:
            root_path = Path(root)
            fake_bin = root_path / "bin"
            fake_bin.mkdir()
            calls = root_path / "bootstrap-calls"
            launchctl = fake_bin / "launchctl"
            launchctl.write_text(
                "#!/bin/sh\n"
                "if [ \"$1\" = bootstrap ]; then\n"
                f"  count=$(cat \"{calls}\" 2>/dev/null || echo 0)\n"
                f"  count=$((count + 1)); echo $count > \"{calls}\"\n"
                "  [ $count -gt 1 ] || exit 5\n"
                "fi\n"
                "exit 0\n",
                encoding="utf-8",
            )
            launchctl.chmod(0o755)
            agent = root_path / "PeppaAgent"
            agent.write_text("#!/bin/sh\n", encoding="utf-8")
            agent.chmod(0o755)
            environment = os.environ | {
                "HOME": root,
                "FATCAT_AGENT_PATH": str(agent),
                "PATH": f"{fake_bin}:/usr/bin:/bin",
            }

            result = subprocess.run(
                ["bash", str(ROOT / "scripts/install-fatcat-launch-agent.sh")],
                env=environment,
                text=True,
                capture_output=True,
                check=False,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(calls.read_text(encoding="utf-8").strip(), "2")


if __name__ == "__main__":
    unittest.main()
