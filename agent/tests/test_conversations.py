import json
import tempfile
import unittest
from pathlib import Path

from peppa_agent.conversations import ConversationStore, SessionConflict


class ConversationStoreTests(unittest.TestCase):
    def test_session_attachment_is_idempotent_and_never_replaced(self):
        with tempfile.TemporaryDirectory() as root:
            store = ConversationStore(Path(root) / "conversations.json")
            store.create("conversation-1", "New chat", root)

            store.attach_session("conversation-1", "session-1")
            store.attach_session("conversation-1", "session-1")

            with self.assertRaises(SessionConflict):
                store.attach_session("conversation-1", "session-2")
            self.assertEqual(store.snapshot()["records"][0]["session_id"], "session-1")

    def test_reopen_preserves_selection_and_session_without_history(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "conversations.json"
            store = ConversationStore(path)
            store.create("conversation-1", "First", root)
            store.attach_session("conversation-1", "session-1")
            reopened = ConversationStore(path).snapshot()

            self.assertEqual(reopened["selected_id"], "conversation-1")
            self.assertEqual(reopened["records"][0]["session_id"], "session-1")
            self.assertNotIn("messages", reopened["records"][0])

    def test_reconnect_lookup_never_creates_a_conversation(self):
        with tempfile.TemporaryDirectory() as root:
            store = ConversationStore(Path(root) / "conversations.json")

            self.assertIsNone(store.get("missing"))
            self.assertEqual(store.snapshot(), {"selected_id": None, "records": []})

    def test_legacy_swift_metadata_is_migrated_before_it_reaches_clients(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "conversations.json"
            path.write_text(json.dumps({
                "selectedID": "conversation-1",
                "records": [{
                    "id": "conversation-1",
                    "title": "Existing chat",
                    "workspacePath": root,
                    "hermesSessionID": "session-1",
                    "lastPreview": "Keep this metadata",
                }],
            }), encoding="utf-8")

            snapshot = ConversationStore(path).snapshot()

            self.assertEqual(snapshot, {
                "selected_id": "conversation-1",
                "records": [{
                    "id": "conversation-1",
                    "title": "Existing chat",
                    "workspace_path": root,
                    "session_id": "session-1",
                }],
            })
            persisted = json.loads(path.read_text(encoding="utf-8"))
            self.assertNotIn("selectedID", persisted)
            self.assertNotIn("workspacePath", persisted["records"][0])

    def test_agent_owns_rename_and_delete_mutations(self):
        with tempfile.TemporaryDirectory() as root:
            store = ConversationStore(Path(root) / "conversations.json")
            store.create("conversation-1", "First", root)
            store.create("conversation-2", "Second", root)

            store.rename("conversation-1", "Renamed")
            store.delete("conversation-2")

            snapshot = store.snapshot()
            self.assertEqual([record["id"] for record in snapshot["records"]], ["conversation-1"])
            self.assertEqual(snapshot["records"][0]["title"], "Renamed")
            self.assertEqual(snapshot["selected_id"], "conversation-1")

    def test_legacy_electron_metadata_is_imported_once(self):
        with tempfile.TemporaryDirectory() as root:
            canonical = Path(root) / "FatCat" / "conversations.json"
            legacy = Path(root) / "fatcat-electron" / "conversations.json"
            legacy.parent.mkdir(parents=True)
            legacy.write_text(json.dumps({
                "selectedId": "electron-1",
                "records": [{
                    "id": "electron-1",
                    "title": "Electron chat",
                    "workspacePath": root,
                    "hermesSessionId": "session-1",
                }],
            }), encoding="utf-8")

            first = ConversationStore(canonical, legacy_paths=[legacy]).snapshot()
            ConversationStore(canonical, legacy_paths=[legacy]).delete("electron-1")
            second = ConversationStore(canonical, legacy_paths=[legacy]).snapshot()

            self.assertEqual(first["selected_id"], "electron-1")
            self.assertEqual(first["records"][0]["session_id"], "session-1")
            self.assertEqual(second, {"selected_id": None, "records": []})

    def test_legacy_transcript_payload_is_discarded(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "conversations.json"
            path.write_text(json.dumps({"selected_id": "c1", "records": [{
                "id": "c1", "title": "First", "workspace_path": root,
                "session_id": "s1", "messages": [{"role": "user", "text": "old"}],
            }]}), encoding="utf-8")

            snapshot = ConversationStore(path).snapshot()

            self.assertNotIn("messages", snapshot["records"][0])


if __name__ == "__main__":
    unittest.main()
