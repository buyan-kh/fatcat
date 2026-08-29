import unittest
from types import SimpleNamespace

from peppa_agent.config_bridge import ConfigBridge


class FakeConfig:
    def __init__(self, initial=None):
        self.current = initial or {}
        self.saved = None

    def load_config(self):
        return {key: value.copy() if isinstance(value, dict) else value for key, value in self.current.items()}

    def save_config(self, value):
        self.saved = value
        self.current = value


class FakeAuth:
    statuses = {
        "openai-codex": {"logged_in": True, "account": "codex@example.test", "access_token": "must-not-leak"},
        "openai-api": {"logged_in": False, "error": "OPENAI_API_KEY is not configured"},
        "anthropic": {"logged_in": True, "detail": "API key configured"},
    }

    def get_auth_status(self, provider):
        return self.statuses[provider]


class FakeModels:
    def provider_model_ids(self, provider, *, force_refresh=False):
        return {
            "openai-codex": ["gpt-5", "gpt-5-mini"],
            "openai-api": ["gpt-4.1"],
            "anthropic": ["claude-sonnet-4-20250514"],
        }[provider]


class FakeCatalog:
    def provider_catalog(self):
        return [
            SimpleNamespace(slug="openai-codex", label="OpenAI Codex", description="Codex subscription", auth_type="oauth_external"),
            SimpleNamespace(slug="openai-api", label="OpenAI API", description="OpenAI API", auth_type="api_key"),
            SimpleNamespace(slug="anthropic", label="Anthropic API", description="Claude models via API", auth_type="api_key"),
            SimpleNamespace(slug="ollama", label="Ollama", description="Local models", auth_type="api_key"),
        ]


class ConfigBridgeTests(unittest.TestCase):
    def make_bridge(self, initial=None):
        config = FakeConfig(initial)
        return ConfigBridge(config, FakeAuth(), FakeModels(), FakeCatalog()), config

    def test_supported_inventory_is_hermes_owned_and_filtered(self):
        bridge, _ = self.make_bridge()

        rows = bridge.inventory()

        self.assertEqual([row["slug"] for row in rows], ["openai-codex", "openai-api", "anthropic"])
        self.assertEqual(rows[0]["status"], "connected")
        self.assertEqual(rows[0]["account"], "codex@example.test")
        self.assertTrue(all(isinstance(value, str) for row in rows for value in row.values()))
        self.assertNotIn("access_token", repr(rows))
        self.assertNotIn("must-not-leak", repr(rows))

    def test_default_selection_persists_provider_and_model_only(self):
        bridge, config = self.make_bridge({"theme": {"name": "dark"}})

        result = bridge.set_default("openai-codex", "gpt-5")

        self.assertEqual(result, {"provider": "openai-codex", "model": "gpt-5"})
        self.assertEqual(config.saved["model"], {"provider": "openai-codex", "default": "gpt-5"})
        self.assertEqual(config.saved["theme"], {"name": "dark"})
        self.assertNotIn("api_key", repr(config.saved))

    def test_credential_reference_persists_without_raw_secret(self):
        bridge, config = self.make_bridge()

        result = bridge.set_credential_ref("openai-api", "fatcat-key:openai-api")

        self.assertEqual(result, {"provider": "openai-api", "credential_ref": "fatcat-key:openai-api"})
        self.assertEqual(config.saved["providers"]["openai-api"], {"credential_ref": "fatcat-key:openai-api"})

    def test_openai_compatible_base_url_is_normalized_and_stays_non_secret(self):
        bridge, config = self.make_bridge({"model": {"provider": "openai-api", "default": "gpt-4.1"}})

        result = bridge.set_base_url("openai-api", "https://llm.example.test/v1/")

        self.assertEqual(result, {"provider": "openai-api", "base_url": "https://llm.example.test/v1"})
        self.assertEqual(config.saved["model"]["base_url"], "https://llm.example.test/v1")
        self.assertNotIn("api_key", repr(config.saved))

    def test_base_url_rejects_embedded_credentials(self):
        bridge, _ = self.make_bridge()

        with self.assertRaises(ValueError):
            bridge.set_base_url("openai-api", "https://user:password@example.test/v1")

    def test_validation_requires_authenticated_provider_and_known_model(self):
        bridge, _ = self.make_bridge()

        connected = bridge.validate("openai-codex", "gpt-5")
        unavailable = bridge.validate("openai-api", "gpt-4.1")
        unknown_model = bridge.validate("anthropic", "missing-model")

        self.assertEqual(connected["usable"], True)
        self.assertEqual(unavailable["usable"], False)
        self.assertEqual(unknown_model["usable"], False)
        self.assertNotIn("must-not-leak", repr((connected, unavailable, unknown_model)))

    def test_invalid_provider_and_empty_values_are_rejected(self):
        bridge, _ = self.make_bridge()

        with self.assertRaises(ValueError):
            bridge.set_default("ollama", "llama3")
        with self.assertRaises(ValueError):
            bridge.set_default("openai-codex", "")
        with self.assertRaises(ValueError):
            bridge.set_credential_ref("openai-api", "raw-api-key")


if __name__ == "__main__":
    unittest.main()
