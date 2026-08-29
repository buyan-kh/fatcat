"""Safe, Hermes-owned configuration operations exposed to FatCat."""

from __future__ import annotations

from typing import Any


class ConfigBridge:
    """Adapt Hermes provider/config APIs to FatCat's non-secret control plane."""

    SUPPORTED_PROVIDERS = ("openai-codex", "openai-api", "anthropic")
    _FORBIDDEN_KEYS = {"api_key", "access_token", "refresh_token", "password", "cookie", "secret"}

    def __init__(self, config: Any, auth: Any, models: Any, catalog: Any):
        self.config = config
        self.auth = auth
        self.models_api = models
        self.catalog = catalog

    @classmethod
    def live(cls) -> "ConfigBridge":
        from hermes_cli import auth, config, models
        from hermes_cli import provider_catalog

        return cls(config, auth, models, provider_catalog)

    def inventory(self) -> list[dict[str, Any]]:
        config = self.config.load_config() or {}
        model_config = config.get("model") if isinstance(config.get("model"), dict) else {}
        default_provider = str(model_config.get("provider") or "").strip()
        default_model = str(model_config.get("default") or "").strip()
        provider_config = config.get("providers") if isinstance(config.get("providers"), dict) else {}
        descriptors = {str(item.slug): item for item in self.catalog.provider_catalog()}

        rows: list[dict[str, Any]] = []
        for provider in self.SUPPORTED_PROVIDERS:
            descriptor = descriptors.get(provider)
            if descriptor is None:
                continue
            status = self._safe_status(provider)
            configured = provider_config.get(provider)
            configured = configured if isinstance(configured, dict) else {}
            credential_ref = configured.get("credential_ref")
            row = {
                "slug": provider,
                "name": str(getattr(descriptor, "label", provider)),
                "description": str(getattr(descriptor, "description", "")),
                "auth_type": str(getattr(descriptor, "auth_type", "api_key")),
                "status": status["status"],
                "detail": status["detail"],
                "account": status.get("account", ""),
                "credential_ref": credential_ref if self._is_reference(credential_ref) else "",
                "is_default": provider == default_provider and bool(default_model),
                "default_model": default_model if provider == default_provider else "",
            }
            rows.append(row)
        return rows

    def models(self, provider: str, *, force_refresh: bool = False) -> list[str]:
        self._require_provider(provider)
        values = self.models_api.provider_model_ids(provider, force_refresh=force_refresh)
        return self._clean_models(values)

    def status(self, provider: str) -> dict[str, Any]:
        self._require_provider(provider)
        return self._safe_status(provider)

    def set_default(self, provider: str, model: str) -> dict[str, str]:
        self._require_provider(provider)
        provider = provider.strip()
        model = model.strip()
        if not model:
            raise ValueError("model is required")
        config = self.config.load_config() or {}
        model_config = config.get("model") if isinstance(config.get("model"), dict) else {}
        model_config = dict(model_config)
        model_config["provider"] = provider
        model_config["default"] = model
        config["model"] = model_config
        self.config.save_config(config)
        return {"provider": provider, "model": model}

    def set_credential_ref(self, provider: str, credential_ref: str) -> dict[str, str]:
        self._require_provider(provider)
        if not self._is_reference(credential_ref):
            raise ValueError("credential_ref must be a FatCat Keychain reference")
        config = self.config.load_config() or {}
        providers = config.get("providers") if isinstance(config.get("providers"), dict) else {}
        providers = dict(providers)
        provider_config = providers.get(provider) if isinstance(providers.get(provider), dict) else {}
        provider_config = dict(provider_config)
        provider_config.pop("api_key", None)
        provider_config.pop("api", None)
        provider_config["credential_ref"] = credential_ref
        providers[provider] = provider_config
        config["providers"] = providers
        self.config.save_config(config)
        return {"provider": provider, "credential_ref": credential_ref}

    def validate(self, provider: str, model: str) -> dict[str, Any]:
        self._require_provider(provider)
        provider = provider.strip()
        model = model.strip()
        if not model:
            raise ValueError("model is required")
        status = self._safe_status(provider)
        if status["status"] != "connected":
            return {"provider": provider, "model": model, "usable": False, "detail": status["detail"]}
        try:
            known_models = self.models(provider)
        except Exception as error:
            return {"provider": provider, "model": model, "usable": False, "detail": self._safe_detail(str(error))}
        if model not in known_models:
            return {"provider": provider, "model": model, "usable": False, "detail": "Model is not in Hermes's current catalog."}
        return {"provider": provider, "model": model, "usable": True, "detail": "Provider and model are available."}

    def _require_provider(self, provider: str) -> None:
        if provider.strip() not in self.SUPPORTED_PROVIDERS:
            raise ValueError(f"Unsupported FatCat provider: {provider}")

    def _safe_status(self, provider: str) -> dict[str, Any]:
        raw = self.auth.get_auth_status(provider) or {}
        logged_in = bool(raw.get("logged_in"))
        error = raw.get("error")
        detail = raw.get("detail") or error or ("Connected" if logged_in else "Not configured")
        result = {
            "status": "connected" if logged_in else "needs_setup",
            "detail": self._safe_detail(str(detail)),
        }
        account = raw.get("account")
        if isinstance(account, str) and account and not self._looks_secret(account):
            result["account"] = account
        return result

    @classmethod
    def _safe_detail(cls, value: str) -> str:
        lowered = value.lower()
        if any(key in lowered for key in cls._FORBIDDEN_KEYS):
            return "Provider returned a credential-related status."
        return value[:240]

    @classmethod
    def _looks_secret(cls, value: str) -> bool:
        lowered = value.lower()
        return any(key in lowered for key in cls._FORBIDDEN_KEYS) or len(value) > 160

    @staticmethod
    def _is_reference(value: Any) -> bool:
        return isinstance(value, str) and value.startswith("fatcat-key:") and value.count(":") == 1 and len(value) > len("fatcat-key:")

    @staticmethod
    def _clean_models(values: Any) -> list[str]:
        if not isinstance(values, (list, tuple)):
            return []
        result: list[str] = []
        for value in values:
            if isinstance(value, str) and value.strip() and value.strip() not in result:
                result.append(value.strip())
        return result
