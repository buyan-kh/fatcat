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


if __name__ == "__main__":
    unittest.main()
