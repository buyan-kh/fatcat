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

    def test_reopen_preserves_selection_session_and_messages(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / "conversations.json"
            store = ConversationStore(path)
            store.create("conversation-1", "First", root)
            store.attach_session("conversation-1", "session-1")
            store.append_message("conversation-1", "message-1", "user", "Hello")

            reopened = ConversationStore(path).snapshot()

            self.assertEqual(reopened["selected_id"], "conversation-1")
            self.assertEqual(reopened["records"][0]["session_id"], "session-1")
            self.assertEqual(reopened["records"][0]["messages"][0]["text"], "Hello")

    def test_reconnect_lookup_never_creates_a_conversation(self):
        with tempfile.TemporaryDirectory() as root:
            store = ConversationStore(Path(root) / "conversations.json")

            self.assertIsNone(store.get("missing"))
            self.assertEqual(store.snapshot(), {"selected_id": None, "records": []})


if __name__ == "__main__":
    unittest.main()
