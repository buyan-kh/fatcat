import asyncio
import threading
import time
import unittest
from types import SimpleNamespace

from pathlib import Path

from peppa_agent.server import PeppaAgentServer, PeppaAgentSession


class MissingProviderAgentSession(PeppaAgentSession):
    def _make_agent(self):
        raise RuntimeError("No LLM provider configured")


class ServerTests(unittest.IsolatedAsyncioTestCase):
    async def test_provider_control_messages_delegate_to_hermes_bridge(self):
        class FakeBridge:
            def inventory(self):
                return [{"slug": "openai-codex", "status": "connected"}]

            def models(self, provider, *, force_refresh=False):
                return [provider, "gpt-5"]

            def set_default(self, provider, model):
                return {"provider": provider, "model": model}

            def set_credential_ref(self, provider, credential_ref):
                return {"provider": provider, "credential_ref": credential_ref}

            def validate(self, provider, model):
                return {"provider": provider, "model": model, "usable": True, "detail": "ok"}

        server = PeppaAgentServer(Path("/tmp/peppa-test.sock"), Path("/tmp/peppa-test-home"), config_bridge=FakeBridge())

        inventory = await server.handle_message({"version": 1, "type": "provider_inventory", "request_id": "r1"}, lambda event: None)
        models = await server.handle_message({"version": 1, "type": "provider_models", "request_id": "r2", "provider_id": "openai-codex", "refresh": True}, lambda event: None)
        selected = await server.handle_message({"version": 1, "type": "provider_set_default", "request_id": "r3", "provider_id": "openai-codex", "model": "gpt-5"}, lambda event: None)
        credential = await server.handle_message({"version": 1, "type": "provider_set_credential_ref", "request_id": "r4", "provider_id": "openai-api", "credential_ref": "fatcat-key:openai-api"}, lambda event: None)
        validation = await server.handle_message({"version": 1, "type": "provider_validate", "request_id": "r5", "provider_id": "openai-codex", "model": "gpt-5"}, lambda event: None)

        self.assertEqual(inventory, {"version": 1, "type": "provider_inventory_result", "request_id": "r1", "providers": [{"slug": "openai-codex", "status": "connected"}]})
        self.assertEqual(models, {"version": 1, "type": "provider_models_result", "request_id": "r2", "provider_id": "openai-codex", "models": ["openai-codex", "gpt-5"]})
        self.assertEqual(selected, {"version": 1, "type": "provider_configured", "request_id": "r3", "operation": "default", "provider": "openai-codex", "model": "gpt-5"})
        self.assertEqual(credential, {"version": 1, "type": "provider_configured", "request_id": "r4", "operation": "credential_ref", "provider": "openai-api", "credential_ref": "fatcat-key:openai-api"})
        self.assertEqual(validation, {"version": 1, "type": "provider_validation_result", "request_id": "r5", "provider": "openai-codex", "model": "gpt-5", "usable": True, "detail": "ok"})

    async def test_provider_control_errors_are_safe_and_never_echo_credentials(self):
        class FailingBridge:
            def set_credential_ref(self, provider, credential_ref):
                raise ValueError("secret value must not be sent")

        server = PeppaAgentServer(Path("/tmp/peppa-test.sock"), Path("/tmp/peppa-test-home"), config_bridge=FailingBridge())
        with self.assertLogs("peppa_agent", level="ERROR") as logs:
            response = await server.handle_message(
                {"version": 1, "type": "provider_set_credential_ref", "request_id": "r1", "provider_id": "openai-api", "credential_ref": "fatcat-key:openai-api"},
                lambda event: None,
            )

        self.assertEqual(response["type"], "error")
        self.assertNotIn("secret value", response["message"])
        self.assertNotIn("fatcat-key", response["message"])
        self.assertNotIn("secret value", "\n".join(logs.output))

    async def test_shutdown_ack_requests_server_shutdown(self):
        server = PeppaAgentServer(Path("/tmp/peppa-test.sock"), Path("/tmp/peppa-test-home"))
        server.shutdown_event = asyncio.Event()

        response = await server.handle_message({"version": 1, "type": "shutdown"}, lambda event: None)

        self.assertEqual(response, {"version": 1, "type": "shutdown_ack"})
        self.assertTrue(server.shutdown_event.is_set())

    async def test_agent_initialization_failure_is_a_typed_error_event(self):
        events = []

        async def emit(event):
            events.append(event)

        session = MissingProviderAgentSession("session-1", ".", emit, asyncio.get_running_loop())
        await session.prompt("request-1", "hello")

        self.assertEqual(events[0]["type"], "state")
        self.assertEqual(events[0]["state"], "sending")
        self.assertEqual(events[0]["session_id"], "session-1")
        self.assertEqual(events[1]["type"], "error")
        self.assertEqual(events[1]["request_id"], "request-1")
        self.assertIn("No LLM provider configured", events[1]["message"])
        self.assertEqual(events[2]["type"], "state")
        self.assertEqual(events[2]["state"], "failed")

    async def test_unknown_user_message_does_not_create_a_replacement_session(self):
        class FakeManager:
            def get_session(self, session_id):
                return None

        server = PeppaAgentServer(Path("/tmp/peppa-test.sock"), Path("/tmp/peppa-test-home"))
        server.session_manager = FakeManager()
        response = await server.handle_message(
            {"version": 1, "type": "user_message", "request_id": "r1", "session_id": "missing", "text": "hello"},
            lambda event: None,
        )

        self.assertEqual(response["type"], "error")
        self.assertIn("not loaded", response["message"])
        self.assertEqual(server.sessions, {})

    async def test_new_and_load_use_stable_session_handles(self):
        class FakeManager:
            def __init__(self):
                self.counter = 0
                self.states = {}

            def create_session(self, cwd):
                self.counter += 1
                session_id = f"session-{self.counter}"
                state = SimpleNamespace(session_id=session_id, cwd=cwd, agent=SimpleNamespace(), history=[])
                self.states[session_id] = state
                return state

            def update_cwd(self, session_id, cwd):
                state = self.states.get(session_id)
                if state:
                    state.cwd = cwd
                return state

        manager = FakeManager()
        server = PeppaAgentServer(Path("/tmp/peppa-test.sock"), Path("/tmp/peppa-test-home"))
        server.session_manager = manager
        first = await server.handle_message(
            {"version": 1, "type": "new_session", "request_id": "r1", "conversation_id": "c1", "cwd": "/tmp"},
            lambda event: None,
        )
        loaded = await server.handle_message(
            {"version": 1, "type": "load_session", "request_id": "r2", "conversation_id": "c1", "session_id": first["session_id"], "cwd": "/tmp"},
            lambda event: None,
        )

        self.assertEqual(first["type"], "session_ready")
        self.assertEqual(loaded["type"], "session_loaded")
        self.assertEqual(first["session_id"], loaded["session_id"])

    async def test_prompts_for_one_session_are_serialized(self):
        class SerialAgent:
            def __init__(self):
                self.active = 0
                self.maximum_active = 0

            def run_conversation(self, *args, **kwargs):
                self.active += 1
                self.maximum_active = max(self.maximum_active, self.active)
                time.sleep(0.03)
                self.active -= 1
                return {"messages": [], "final_response": "done"}

        agent = SerialAgent()
        state = SimpleNamespace(agent=agent, history=[], cancel_event=threading.Event())
        events = []

        async def emit(event):
            events.append(event)

        session = PeppaAgentSession("session-1", ".", emit, asyncio.get_running_loop(), state)
        await asyncio.gather(session.prompt("request-1", "one"), session.prompt("request-2", "two"))

        self.assertEqual(agent.maximum_active, 1)

    async def test_cancelled_turn_is_reported_as_failed_not_completed(self):
        class InterruptibleAgent:
            def run_conversation(self, *args, **kwargs):
                time.sleep(0.03)
                return {"messages": [], "final_response": "", "interrupted": state.cancel_event.is_set()}

        state = SimpleNamespace(agent=None, history=[], cancel_event=threading.Event())
        state.agent = InterruptibleAgent()
        events = []

        async def emit(event):
            events.append(event)

        session = PeppaAgentSession("session-1", ".", emit, asyncio.get_running_loop(), state)
        prompt_task = asyncio.create_task(session.prompt("request-1", "hello"))
        await asyncio.sleep(0.005)
        state.cancel_event.set()
        await prompt_task

        self.assertEqual(events[-1]["type"], "state")
        self.assertEqual(events[-1]["state"], "failed")
        self.assertEqual(events[-1]["session_id"], "session-1")

    async def test_prompt_uses_the_supported_acp_prompt_method_when_available(self):
        class FakeACP:
            def __init__(self):
                self.calls = []

            async def prompt(self, *, prompt, session_id):
                self.calls.append((prompt[0].text, session_id))
                return SimpleNamespace(stop_reason="end_turn")

        acp_agent = FakeACP()
        state = SimpleNamespace(agent=SimpleNamespace(), history=[], cancel_event=threading.Event())
        events = []

        async def emit(event):
            events.append(event)

        session = PeppaAgentSession(
            "session-1", ".", emit, asyncio.get_running_loop(), state, acp_agent=acp_agent
        )
        await session.prompt("request-1", "hello")

        self.assertEqual(acp_agent.calls, [("hello", "session-1")])


if __name__ == "__main__":
    unittest.main()
