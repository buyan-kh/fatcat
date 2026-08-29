"""Headless FatCat Agent socket server.

The Swift app owns the process and permissions. This process owns Hermes
conversation state and emits only typed JSON events on the Unix socket.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import os
import uuid
from pathlib import Path
from typing import Any

LOG = logging.getLogger("peppa_agent")
FORBIDDEN_KEYS = {"api_key", "access_token", "refresh_token", "cookie", "password", "secret"}


def _reject_credentials(value: Any, path: str = "") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if str(key).lower() in FORBIDDEN_KEYS:
                raise ValueError(f"credential field is not allowed: {path}{key}")
            _reject_credentials(child, f"{path}{key}.")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            _reject_credentials(child, f"{path}{index}.")


def _event(event_type: str, **fields: Any) -> dict[str, Any]:
    return {"version": 1, "type": event_type, **fields}


class PeppaAgentSession:
    def __init__(
        self,
        session_id: str,
        cwd: str,
        emit,
        loop: asyncio.AbstractEventLoop,
        state=None,
        session_manager=None,
        acp_agent=None,
    ):
        self.session_id = session_id
        self.cwd = cwd
        self.emit = emit
        self.loop = loop
        self.state = state
        self.session_manager = session_manager
        self.acp_agent = acp_agent
        self.agent = state.agent if state is not None else None
        self.prompt_lock = asyncio.Lock()
        self.current_request_id: str | None = None
        if self.agent is not None:
            self.agent.tool_start_callback = self._tool_started
            self.agent.tool_complete_callback = self._tool_completed

    def _state_event(self, state: str, request_id: str | None = None) -> dict[str, Any]:
        return _event("state", state=state, session_id=self.session_id, request_id=request_id)

    async def prompt(self, request_id: str, text: str) -> None:
        # Hermes ACP serializes turns for a session. Keep that invariant at the
        # FatCat boundary as well so history, callbacks, and cancellation cannot
        # race when the composer submits another prompt quickly.
        async with self.prompt_lock:
            await self.emit(self._state_event("sending", request_id))
            try:
                if self.agent is None:
                    self.agent = self._make_agent()
                if self.state is not None and self.state.cancel_event:
                    self.state.cancel_event.clear()
                self.current_request_id = request_id
                if self.acp_agent is not None:
                    try:
                        from acp.schema import TextContentBlock
                    except ImportError:  # lightweight test doubles need no ACP install
                        from types import SimpleNamespace

                        TextContentBlock = lambda **fields: SimpleNamespace(**fields)

                    response = await self.acp_agent.prompt(
                        prompt=[TextContentBlock(type="text", text=text)],
                        session_id=self.session_id,
                    )
                    cancelled = bool(
                        self.state is not None
                        and self.state.cancel_event
                        and self.state.cancel_event.is_set()
                    )
                    succeeded = getattr(response, "stop_reason", None) == "end_turn" and not cancelled
                else:
                    succeeded = await asyncio.to_thread(self._run, request_id, text)
                await self.emit(self._state_event("completed" if succeeded else "failed", request_id))
            except Exception as error:  # surface initialization failures as protocol events
                LOG.exception("Hermes could not start a turn")
                await self.emit(_event("error", request_id=request_id, message=str(error)))
                await self.emit(self._state_event("failed", request_id))
            finally:
                self.current_request_id = None

    def _make_agent(self):
        # Hermes remains the implementation of the agent loop, model routing,
        # tools, skills, memory, and persistence. This import is resolved from
        # the pinned source tree staged beside this package in the app bundle.
        from run_agent import AIAgent

        return AIAgent(
            model=os.environ.get("PEPPA_MODEL", ""),
            platform="peppa",
            quiet_mode=True,
            load_soul_identity=False,
            skip_background_review=True,
            tool_start_callback=self._tool_started,
            tool_complete_callback=self._tool_completed,
            ephemeral_system_prompt="""
You are FatCat Agent, the headless Hermes runtime inside FatCat.
FatCat is local-first. Treat screen context as privacy-filtered and never ask
for or emit browser cookies, OAuth tokens, API keys, passwords, or credentials.
For computer work, propose typed native actions such as read_screen_context,
inspect_accessibility_tree, open_application, open_file, type_text,
click_element, move_window, and verify_screen_result. The Swift host classifies
risk, requests approval, executes, and independently verifies; you do not
execute OS mutations directly or bypass that handshake.
""",
        )

    def _tool_started(self, tool_call_id: str, name: str, arguments: dict[str, Any]) -> None:
        safe_arguments = {
            str(key): value if isinstance(value, str) else json.dumps(value, separators=(",", ":"))
            for key, value in arguments.items()
        }
        _reject_credentials(safe_arguments)
        self.emit_sync(_event("tool_call", request_id=tool_call_id, name=name, arguments=safe_arguments))

    def _tool_completed(self, tool_call_id: str, name: str, arguments: dict[str, Any], result: Any) -> None:
        self.emit_sync(_event("action_result", request_id=tool_call_id, success=True, detail=f"Tool {name} completed."))

    def _run(self, request_id: str, text: str) -> bool:
        def stream_delta(delta: str) -> None:
            if delta:
                self.emit_sync(self._state_event("streaming", request_id))
                self.emit_sync(_event("assistant_delta", request_id=request_id, session_id=self.session_id, text=delta))

        self.emit_sync(self._state_event("working", request_id))
        try:
            self.agent.stream_delta_callback = stream_delta
            result = {}
            if self.state is None:
                self.agent.run_conversation(text, task_id=request_id)
            else:
                result = self.agent.run_conversation(
                    text,
                    conversation_history=self.state.history,
                    task_id=self.session_id,
                    persist_user_message=text,
                )
                if isinstance(result, dict) and result.get("messages"):
                    self.state.history = result["messages"]
                    if self.session_manager is not None:
                        self.session_manager.save_session(self.session_id)
            return not (
                self.state is not None
                and (
                    bool(result.get("interrupted"))
                    or bool(self.state.cancel_event and self.state.cancel_event.is_set())
                )
            )
        except Exception as error:  # surface a typed error; keep daemon alive
            LOG.exception("Hermes turn failed")
            self.emit_sync(_event("error", request_id=request_id, message=str(error)))
            return False

    def emit_sync(self, event: dict[str, Any]) -> None:
        # The callback is marshalled back to the event loop by the connection.
        self.loop.call_soon_threadsafe(asyncio.create_task, self.emit(event))


class _FatCatACPBridge:
    """Translate Hermes ACP notifications into FatCat's small local protocol."""

    def __init__(self, server: "PeppaAgentServer"):
        self.server = server

    async def session_update(self, session_id: str, update: Any, **kwargs: Any) -> None:
        session = self.server.sessions.get(session_id)
        if session is None:
            return
        request_id = session.current_request_id
        kind = getattr(update, "session_update", "")
        if kind == "agent_message_chunk":
            text = getattr(getattr(update, "content", None), "text", None)
            if text:
                await session.emit(session._state_event("streaming", request_id))
                await session.emit(_event("assistant_delta", request_id=request_id, session_id=session_id, text=text))
        elif kind == "agent_thought_chunk":
            await session.emit(session._state_event("thinking", request_id))
        elif kind == "plan":
            steps = [str(getattr(entry, "content", "")) for entry in (getattr(update, "entries", None) or [])]
            await session.emit(_event("plan", request_id=request_id, session_id=session_id, steps=steps))
        elif kind == "tool_call":
            arguments = getattr(update, "raw_input", None)
            if not isinstance(arguments, dict):
                arguments = {"raw": str(arguments or "")}
            safe_arguments = {
                str(key): value if isinstance(value, str) else json.dumps(value, separators=(",", ":"))
                for key, value in arguments.items()
            }
            _reject_credentials(safe_arguments)
            await session.emit(_event(
                "tool_call",
                request_id=str(getattr(update, "tool_call_id", request_id)),
                name=str(getattr(update, "title", "tool")),
                arguments=safe_arguments,
            ))
        elif kind == "tool_call_update":
            status = str(getattr(getattr(update, "status", None), "value", getattr(update, "status", "")))
            if status in {"completed", "failed"}:
                await session.emit(_event(
                    "action_result",
                    request_id=str(getattr(update, "tool_call_id", request_id)),
                    success=status == "completed",
                    detail=f"Tool call {status}.",
                ))

    async def request_permission(self, options: list[Any], session_id: str, tool_call: Any, **kwargs: Any) -> Any:
        session = self.server.sessions.get(session_id)
        if session is not None:
            await session.emit(_event(
                "permission_request",
                request_id=str(getattr(tool_call, "tool_call_id", session.current_request_id or uuid.uuid4())),
                action=str(getattr(tool_call, "title", "native action")),
                risk="high",
                reason="FatCat Agent requested a native action approval.",
            ))
        from acp.schema import DeniedOutcome, RequestPermissionResponse

        return RequestPermissionResponse(outcome=DeniedOutcome(outcome="cancelled"))


class PeppaAgentServer:
    def __init__(self, socket_path: Path, hermes_home: Path, config_bridge=None):
        self.socket_path = socket_path
        self.hermes_home = hermes_home
        self.sessions: dict[str, PeppaAgentSession] = {}
        self.session_manager = None
        self.acp_agent = None
        self.config_bridge = config_bridge
        self.loop: asyncio.AbstractEventLoop | None = None
        self.active_writer: asyncio.StreamWriter | None = None
        self.shutdown_event: asyncio.Event | None = None

    async def start(self) -> None:
        self.loop = asyncio.get_running_loop()
        self.socket_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            self.socket_path.unlink()
        except FileNotFoundError:
            pass
        os.environ["HERMES_HOME"] = str(self.hermes_home)
        # Use Hermes ACP's SessionManager as the source of truth. It persists
        # the ACP session and restores it from Hermes' state database after a
        # process restart; the Swift app only stores the stable session handle.
        from acp_adapter.session import SessionManager
        from acp_adapter.server import HermesACPAgent
        self.session_manager = SessionManager()
        self.acp_agent = HermesACPAgent(session_manager=self.session_manager)
        self.acp_agent._conn = _FatCatACPBridge(self)
        self.shutdown_event = asyncio.Event()
        server = await asyncio.start_unix_server(self.handle_client, path=str(self.socket_path))
        os.chmod(self.socket_path, 0o600)
        LOG.info("FatCat Agent listening on %s", self.socket_path)
        try:
            async with server:
                await self.shutdown_event.wait()
                server.close()
                await server.wait_closed()
        finally:
            try:
                self.socket_path.unlink()
            except FileNotFoundError:
                pass

    async def handle_client(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        if self.active_writer is not None:
            writer.write((json.dumps(_event("error", request_id=None, message="FatCat Agent accepts one local client at a time"), separators=(",", ":")) + "\n").encode())
            await writer.drain()
            writer.close()
            await writer.wait_closed()
            return
        self.active_writer = writer

        async def emit(event: dict[str, Any]) -> None:
            writer.write((json.dumps(event, separators=(",", ":")) + "\n").encode())
            await writer.drain()

        try:
            async for raw_line in reader:
                if not raw_line.strip():
                    continue
                try:
                    message = json.loads(raw_line)
                    _reject_credentials(message)
                    response = await self.handle_message(message, emit)
                    if response is not None:
                        await emit(response)
                    if message.get("type") == "shutdown":
                        break
                except Exception as error:
                    await emit(_event("error", request_id=None, message=str(error)))
        finally:
            self.active_writer = None
            writer.close()
            await writer.wait_closed()

    async def handle_message(self, message: dict[str, Any], emit) -> dict[str, Any] | None:
        if message.get("version") != 1:
            raise ValueError("unsupported protocol version")
        message_type = message.get("type")
        if message_type == "hello":
            return _event("hello_ack", agent_version="fatcat-agent")
        if message_type == "new_session":
            manager = self._require_session_manager()
            conversation_id = str(message.get("conversation_id") or "")
            cwd = self._explicit_cwd(message.get("cwd"))
            if not conversation_id:
                raise ValueError("conversation_id is required")
            if self.acp_agent is not None:
                response = await self.acp_agent.new_session(cwd=cwd)
                state = manager.get_session(response.session_id)
            else:
                state = manager.create_session(cwd=cwd)
            if state is None:
                raise RuntimeError("Hermes ACP created no usable session")
            self.sessions[state.session_id] = PeppaAgentSession(
                state.session_id, cwd, emit, self.loop or asyncio.get_running_loop(), state, manager, self.acp_agent
            )
            return _event("session_ready", request_id=str(message.get("request_id") or uuid.uuid4()), conversation_id=conversation_id, session_id=state.session_id)
        if message_type == "load_session":
            manager = self._require_session_manager()
            conversation_id = str(message.get("conversation_id") or "")
            session_id = str(message.get("session_id") or "")
            cwd = self._explicit_cwd(message.get("cwd"))
            if self.acp_agent is not None:
                response = await self.acp_agent.load_session(cwd=cwd, session_id=session_id)
                state = manager.get_session(session_id) if response is not None else None
            else:
                state = manager.update_cwd(session_id, cwd)
            request_id = str(message.get("request_id") or uuid.uuid4())
            if state is None:
                return _event("session_load_failed", request_id=request_id, conversation_id=conversation_id, session_id=session_id, message="Hermes could not load this conversation. Start a new chat to continue.")
            self.sessions[session_id] = PeppaAgentSession(
                session_id, cwd, emit, self.loop or asyncio.get_running_loop(), state, manager, self.acp_agent
            )
            for item in state.history:
                role = str(item.get("role") or "")
                text = item.get("content")
                if role in {"user", "assistant"} and isinstance(text, str) and text:
                    await emit(_event("session_history", conversation_id=conversation_id, session_id=session_id, role=role, text=text))
            return _event("session_loaded", request_id=request_id, conversation_id=conversation_id, session_id=session_id)
        if message_type == "list_sessions":
            manager = self._require_session_manager()
            cwd_value = message.get("cwd")
            cwd = self._explicit_cwd(cwd_value) if cwd_value else None
            if self.acp_agent is not None:
                response = await self.acp_agent.list_sessions(cwd=cwd)
                sessions = [item.model_dump(mode="json", by_alias=True, exclude_none=True) for item in response.sessions]
            else:
                sessions = manager.list_sessions(cwd=cwd)
            safe_sessions = [
                {
                    "session_id": str(item.get("session_id") or ""),
                    "cwd": str(item.get("cwd") or ""),
                    "title": str(item.get("title") or ""),
                    "updated_at": str(item.get("updated_at") or ""),
                }
                for item in sessions
            ]
            return _event("session_list", request_id=str(message.get("request_id") or uuid.uuid4()), sessions=safe_sessions)
        if message_type == "cancel":
            manager = self._require_session_manager()
            session_id = str(message.get("session_id") or "")
            if self.acp_agent is not None:
                await self.acp_agent.cancel(session_id=session_id)
                state = manager.get_session(session_id)
            else:
                state = manager.get_session(session_id)
            if state is None:
                return _event("error", request_id=str(message.get("request_id") or uuid.uuid4()), message="Hermes session is no longer available.")
            if state.cancel_event:
                state.cancel_event.set()
            try:
                from agent.interrupt_compat import request_hard_interrupt
                request_hard_interrupt(state.agent)
            except Exception:
                LOG.debug("Hermes cancellation interrupt was unavailable", exc_info=True)
            return _event("state", state="stopping", session_id=session_id, request_id=str(message.get("request_id") or uuid.uuid4()))
        if message_type in {
            "provider_inventory",
            "provider_models",
            "provider_set_default",
            "provider_set_credential_ref",
            "provider_validate",
        }:
            return self._handle_provider_message(message)
        if message_type == "observation":
            return None
        if message_type == "shutdown":
            if self.shutdown_event is not None:
                self.shutdown_event.set()
            return _event("shutdown_ack")
        if message_type != "user_message":
            raise ValueError(f"unsupported message type: {message_type}")
        session_id = str(message.get("session_id") or "")
        request_id = str(message.get("request_id") or uuid.uuid4())
        session = self.sessions.get(session_id)
        if session is None:
            manager = self._require_session_manager()
            state = manager.get_session(session_id)
            if state is None:
                return _event("error", request_id=request_id, message="Hermes session is not loaded. Reopen the conversation or start a new chat.")
            session = PeppaAgentSession(
                session_id, state.cwd, emit, self.loop or asyncio.get_running_loop(), state, manager, self.acp_agent
            )
            self.sessions[session_id] = session
        asyncio.create_task(session.prompt(request_id, str(message.get("text") or "")))
        return _event("state", state="thinking", session_id=session_id, request_id=request_id)

    def _handle_provider_message(self, message: dict[str, Any]) -> dict[str, Any]:
        request_id = str(message.get("request_id") or uuid.uuid4())
        try:
            bridge = self._require_config_bridge()
            message_type = message["type"]
            if message_type == "provider_inventory":
                return _event("provider_inventory_result", request_id=request_id, providers=bridge.inventory())
            provider = self._required_text(message, "provider_id")
            if message_type == "provider_models":
                models = bridge.models(provider, force_refresh=bool(message.get("refresh", False)))
                return _event("provider_models_result", request_id=request_id, provider_id=provider, models=models)
            if message_type == "provider_set_default":
                result = bridge.set_default(provider, self._required_text(message, "model"))
                return _event("provider_configured", request_id=request_id, operation="default", **result)
            if message_type == "provider_set_credential_ref":
                result = bridge.set_credential_ref(provider, self._required_text(message, "credential_ref"))
                return _event("provider_configured", request_id=request_id, operation="credential_ref", **result)
            result = bridge.validate(provider, self._required_text(message, "model"))
            return _event("provider_validation_result", request_id=request_id, **result)
        except Exception:
            LOG.error("Hermes provider control operation failed")
            return _event("error", request_id=request_id, message="Provider setup operation failed.")

    def _require_config_bridge(self):
        if self.config_bridge is None:
            from peppa_agent.config_bridge import ConfigBridge

            self.config_bridge = ConfigBridge.live()
        return self.config_bridge

    @staticmethod
    def _required_text(message: dict[str, Any], key: str) -> str:
        value = message.get(key)
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"{key} is required")
        return value.strip()

    def _require_session_manager(self):
        if self.session_manager is None:
            from acp_adapter.session import SessionManager
            self.session_manager = SessionManager()
        return self.session_manager

    def _explicit_cwd(self, value: Any) -> str:
        candidate = Path(str(value or "")).expanduser()
        if candidate.is_dir():
            return str(candidate.resolve())
        fallback = self.hermes_home / "workspace"
        fallback.mkdir(parents=True, exist_ok=True)
        return str(fallback.resolve())


def main() -> None:
    parser = argparse.ArgumentParser(prog="FatCatAgent")
    parser.add_argument("--socket", required=True, type=Path)
    parser.add_argument("--hermes-home", required=True, type=Path)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    asyncio.run(PeppaAgentServer(args.socket, args.hermes_home).start())


if __name__ == "__main__":
    main()
