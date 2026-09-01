"""Canonical local conversation metadata for every FatCat client."""

from __future__ import annotations

import json
import os
import threading
from copy import deepcopy
from pathlib import Path


class SessionConflict(ValueError):
    """Raised when code tries to silently replace a saved Hermes session."""


class ConversationStore:
    def __init__(self, path: Path, legacy_paths: list[Path] | tuple[Path, ...] = ()):
        self.path = path
        self.migration_path = path.with_suffix(path.suffix + ".migrations")
        self._lock = threading.RLock()
        self._document, migrated = self._load()
        completed_migrations = self._load_completed_migrations()
        migrations_changed = False
        for legacy_path in legacy_paths:
            migration_key = str(legacy_path.expanduser().resolve())
            if legacy_path == path or migration_key in completed_migrations or not legacy_path.exists():
                continue
            try:
                legacy, _ = self._load_path(legacy_path)
            except ValueError:
                continue
            known_ids = {record["id"] for record in self._document["records"]}
            additions = [record for record in legacy["records"] if record["id"] not in known_ids]
            if additions:
                self._document["records"].extend(additions)
                migrated = True
            if self._document["selected_id"] is None and legacy["selected_id"] in {record["id"] for record in self._document["records"]}:
                self._document["selected_id"] = legacy["selected_id"]
                migrated = True
            completed_migrations.add(migration_key)
            migrations_changed = True
        if migrated:
            self._save()
        if migrations_changed:
            self._save_completed_migrations(completed_migrations)

    def snapshot(self) -> dict:
        with self._lock:
            return deepcopy(self._document)

    def get(self, conversation_id: str) -> dict | None:
        with self._lock:
            record = self._find(conversation_id)
            return deepcopy(record) if record else None

    def find_by_session(self, session_id: str) -> dict | None:
        with self._lock:
            record = next((item for item in self._document["records"] if item.get("session_id") == session_id), None)
            return deepcopy(record) if record else None

    def create(self, conversation_id: str, title: str, workspace_path: str) -> dict:
        conversation_id = conversation_id.strip()
        if not conversation_id:
            raise ValueError("conversation_id is required")
        with self._lock:
            if self._find(conversation_id):
                raise ValueError(f"conversation already exists: {conversation_id}")
            record = {
                "id": conversation_id,
                "title": title.strip() or "New chat",
                "workspace_path": str(Path(workspace_path).expanduser()),
                "session_id": None,
                "messages": [],
            }
            self._document["records"].append(record)
            self._document["selected_id"] = conversation_id
            self._save()
            return deepcopy(record)

    def select(self, conversation_id: str) -> None:
        with self._lock:
            if self._find(conversation_id) is None:
                raise KeyError(conversation_id)
            self._document["selected_id"] = conversation_id
            self._save()

    def rename(self, conversation_id: str, title: str) -> None:
        title = title.strip()
        if not title:
            raise ValueError("title is required")
        with self._lock:
            self._required(conversation_id)["title"] = title
            self._save()

    def delete(self, conversation_id: str) -> None:
        with self._lock:
            self._required(conversation_id)
            self._document["records"] = [
                record for record in self._document["records"] if record["id"] != conversation_id
            ]
            if self._document["selected_id"] == conversation_id:
                self._document["selected_id"] = (
                    self._document["records"][0]["id"] if self._document["records"] else None
                )
            self._save()

    def attach_session(self, conversation_id: str, session_id: str) -> None:
        session_id = session_id.strip()
        if not session_id:
            raise ValueError("session_id is required")
        with self._lock:
            record = self._required(conversation_id)
            existing = record.get("session_id")
            if existing and existing != session_id:
                raise SessionConflict(f"conversation {conversation_id} is already attached to {existing}")
            if existing == session_id:
                return
            record["session_id"] = session_id
            self._save()

    def append_message(self, conversation_id: str, message_id: str, role: str, text: str) -> dict:
        if role not in {"user", "assistant", "system"}:
            raise ValueError(f"unsupported message role: {role}")
        with self._lock:
            record = self._required(conversation_id)
            existing = next((item for item in record["messages"] if item["id"] == message_id), None)
            if existing:
                return deepcopy(existing)
            message = {"id": message_id, "role": role, "text": text}
            record["messages"].append(message)
            self._save()
            return deepcopy(message)

    def append_assistant_delta(self, conversation_id: str, message_id: str, text: str) -> dict:
        with self._lock:
            record = self._required(conversation_id)
            message = next((item for item in record["messages"] if item["id"] == message_id), None)
            if message is None:
                message = {"id": message_id, "role": "assistant", "text": ""}
                record["messages"].append(message)
            message["text"] += text
            self._save()
            return deepcopy(message)

    def merge_history(self, conversation_id: str, session_id: str, history: list[dict]) -> None:
        with self._lock:
            record = self._required(conversation_id)
            existing = record["messages"]
            used: set[int] = set()
            cursor = 0
            merged = []
            for history_index, item in enumerate(history):
                role = item.get("role")
                text = item.get("content")
                if role not in {"user", "assistant"} or not isinstance(text, str) or not text:
                    continue
                match = next((
                    index for index in range(cursor, len(existing))
                    if index not in used and existing[index]["role"] == role and existing[index]["text"] == text
                ), None)
                if match is None:
                    merged.append({"id": f"history-{session_id}-{history_index}", "role": role, "text": text})
                else:
                    merged.append(deepcopy(existing[match]))
                    used.add(match)
                    cursor = match + 1
            merged.extend(deepcopy(item) for index, item in enumerate(existing) if index not in used)
            if merged != existing:
                record["messages"] = merged
                self._save()

    def _load(self) -> tuple[dict, bool]:
        return self._load_path(self.path)

    def _load_completed_migrations(self) -> set[str]:
        try:
            value = json.loads(self.migration_path.read_text(encoding="utf-8"))
        except (FileNotFoundError, OSError, json.JSONDecodeError):
            return set()
        return {item for item in value if isinstance(item, str)} if isinstance(value, list) else set()

    def _save_completed_migrations(self, completed: set[str]) -> None:
        self.migration_path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.migration_path.with_suffix(self.migration_path.suffix + ".tmp")
        temporary.write_text(json.dumps(sorted(completed), separators=(",", ":")), encoding="utf-8")
        os.replace(temporary, self.migration_path)

    def _load_path(self, path: Path) -> tuple[dict, bool]:
        try:
            value = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return {"selected_id": None, "records": []}, False
        except (OSError, json.JSONDecodeError) as error:
            raise ValueError(f"invalid conversation store: {error}") from error
        if not isinstance(value, dict) or not isinstance(value.get("records"), list):
            raise ValueError("invalid conversation store document")
        normalized = self._normalize_document(value)
        return normalized, normalized != value

    def _normalize_document(self, value: dict) -> dict:
        records = []
        for raw in value["records"]:
            if not isinstance(raw, dict) or not isinstance(raw.get("id"), str) or not raw["id"].strip():
                continue
            conversation_id = raw["id"].strip()
            title = raw.get("title") if isinstance(raw.get("title"), str) else "New chat"
            workspace = raw.get("workspace_path") or raw.get("workspacePath") or str(Path.home())
            session_id = raw.get("session_id") or raw.get("hermesSessionID") or raw.get("hermesSessionId")
            messages = []
            for index, message in enumerate(raw.get("messages") if isinstance(raw.get("messages"), list) else []):
                if not isinstance(message, dict):
                    continue
                role = message.get("role")
                text = message.get("text")
                if role not in {"user", "assistant", "system"} or not isinstance(text, str):
                    continue
                message_id = message.get("id")
                if not isinstance(message_id, str) or not message_id.strip():
                    message_id = f"legacy-{conversation_id}-{index}"
                messages.append({"id": message_id, "role": role, "text": text})
            records.append({
                "id": conversation_id,
                "title": title.strip() or "New chat",
                "workspace_path": str(workspace),
                "session_id": session_id if isinstance(session_id, str) and session_id.strip() else None,
                "messages": messages,
            })
        selected_id = value.get("selected_id") or value.get("selectedID") or value.get("selectedId")
        if not isinstance(selected_id, str) or not any(record["id"] == selected_id for record in records):
            selected_id = None
        return {"selected_id": selected_id, "records": records}

    def _find(self, conversation_id: str) -> dict | None:
        return next((item for item in self._document["records"] if item.get("id") == conversation_id), None)

    def _required(self, conversation_id: str) -> dict:
        record = self._find(conversation_id)
        if record is None:
            raise KeyError(conversation_id)
        return record

    def _save(self) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(self.path.suffix + ".tmp")
        temporary.write_text(json.dumps(self._document, separators=(",", ":")), encoding="utf-8")
        os.replace(temporary, self.path)
