import Foundation
import Testing
@testable import PeppaAnywhereCore

struct PeppaIPCTests {
    @Test func roundTripsSharedClientAndConversationEvents() throws {
        let message = FatCatIPCMessageRecord(id: "m1", role: "user", text: "Hello")
        let record = FatCatIPCConversationRecord(
            id: "c1",
            title: "First",
            workspacePath: "/tmp",
            sessionID: "s1",
            messages: [message]
        )
        let messages: [PeppaIPCMessage] = [
            .clientHello(client: "native_pet"),
            .petClicked(eventID: "click-1", petID: "primary", conversationID: "c1"),
            .conversationSnapshot(selectedID: "c1", records: [record]),
            .messageAdded(conversationID: "c1", sessionID: "s1", message: message)
        ]

        for message in messages {
            #expect(try PeppaIPCCodec.decodeLine(PeppaIPCCodec.encode(message: message)) == message)
        }
    }

    @Test func providerSetupMessagesRoundTripWithoutRawCredentials() throws {
        let messages: [PeppaIPCMessage] = [
            .providerInventory(requestID: "inventory-1"),
            .providerModels(requestID: "models-1", providerID: "openai-codex", refresh: true),
            .providerSetDefault(requestID: "default-1", providerID: "openai-codex", model: "gpt-5"),
            .providerSetCredentialRef(requestID: "credential-1", providerID: "openai-api", credentialRef: "fatcat-key:openai-api"),
            .providerSetBaseURL(requestID: "url-1", providerID: "openai-api", baseURL: "https://api.example.test/v1"),
            .providerValidate(requestID: "validate-1", providerID: "anthropic", model: "claude-sonnet-4-20250514"),
            .providerInventoryResult(requestID: "inventory-1", providers: [["slug": "openai-codex", "status": "connected"]]),
            .providerModelsResult(requestID: "models-1", providerID: "openai-codex", models: ["gpt-5"]),
            .providerConfigured(requestID: "default-1", operation: "default", provider: "openai-codex", model: "gpt-5", credentialRef: nil),
            .providerConfigured(requestID: "credential-1", operation: "credential_ref", provider: "openai-api", model: nil, credentialRef: "fatcat-key:openai-api"),
            .providerValidationResult(requestID: "validate-1", provider: "anthropic", model: "claude-sonnet-4-20250514", usable: true, detail: "Provider and model are available.")
        ]

        for message in messages {
            #expect(try PeppaIPCCodec.decodeLine(PeppaIPCCodec.encode(message: message)) == message)
        }
    }

    @Test func providerSetupMessagesRejectRawCredentialFields() throws {
        let raw = "{\"version\":1,\"type\":\"provider_set_default\",\"request_id\":\"r1\",\"provider_id\":\"openai-api\",\"model\":\"gpt-5\",\"api_key\":\"sk-live\"}"
        #expect(throws: PeppaIPCError.credentialField("api_key")) {
            try PeppaIPCCodec.decodeLine(raw)
        }
    }

    @Test func encodesTypedMessagesAsOneNewlineDelimitedRecord() throws {
        let message = PeppaIPCMessage.userMessage(
            requestID: "request-1",
            conversationID: "conversation-1",
            sessionID: "session-1",
            text: "What is open?"
        )

        let encoded = try PeppaIPCCodec.encode(message: message)
        let decoded = try PeppaIPCCodec.decodeLine(encoded)

        #expect(encoded.last == 0x0A)
        #expect(decoded == message)
    }

    @Test func decodesStreamingAssistantAndStateEvents() throws {
        let assistant = try PeppaIPCCodec.decodeLine(#"{"version":1,"type":"assistant_delta","request_id":"r1","session_id":"s1","text":"Hello"}"# + "\n")
        let state = try PeppaIPCCodec.decodeLine(#"{"version":1,"type":"state","state":"thinking"}"# + "\n")

        #expect(assistant == .assistantDelta(requestID: "r1", sessionID: "s1", text: "Hello"))
        #expect(state == .state(.thinking))
    }

    @Test func decodesSessionScopedStateEvents() throws {
        let state = try PeppaIPCCodec.decodeLine(#"{"version":1,"type":"state","state":"completed","session_id":"s1","request_id":"r1"}"# + "\n")

        #expect(state == .sessionState(.completed, sessionID: "s1", requestID: "r1"))
    }

    @Test func encodesObservationNullsAsValidJSON() throws {
        let data = try PeppaIPCCodec.encode(message: .observation(requestID: nil, activeApp: "Xcode", window: nil, visibleText: [], confidence: 0.8))
        #expect(try PeppaIPCCodec.decodeLine(data) == .observation(requestID: nil, activeApp: "Xcode", window: nil, visibleText: [], confidence: 0.8))
    }

    @Test func rejectsMalformedOrCredentialBearingMessages() throws {
        #expect(throws: PeppaIPCError.self) {
            try PeppaIPCCodec.decodeLine(Data("not json\n".utf8))
        }
        #expect(throws: PeppaIPCError.self) {
        try PeppaIPCCodec.decodeLine(Data((#"{"version":1,"type":"assistant_delta","api_key":"secret"}"# + "\n").utf8))
        }
    }

    @Test func roundTripsPlansToolCallsProviderStatusAndShutdown() throws {
        let messages: [PeppaIPCMessage] = [
            .plan(requestID: "r1", sessionID: "s1", steps: ["Inspect context", "Explain next step"]),
            .toolCall(requestID: "r1", name: "read_screen_context", arguments: ["scope": "focused"]),
            .providerStatus(providerID: "ollama", authenticated: true, detail: "2 models available"),
            .shutdown,
            .shutdownAck
        ]

        for message in messages {
            #expect(try PeppaIPCCodec.decodeLine(PeppaIPCCodec.encode(message: message)) == message)
        }
    }

    @Test func roundTripsGenericHermesEvents() throws {
        let event = FatCatHermesEvent(
            eventID: "event-1",
            kind: "tool.needs_approval",
            sessionID: "session-1",
            requestID: "request-1",
            summary: "Send email to Sarah",
            details: ["tool": "send_email", "risk": "high"]
        )

        #expect(try PeppaIPCCodec.decodeLine(PeppaIPCCodec.encode(message: .hermesEvent(event))) == .hermesEvent(event))
    }

    @Test func roundTripsConversationLifecycleAndCancellation() throws {
        let messages: [PeppaIPCMessage] = [
            .newSession(requestID: "r1", conversationID: "c1", cwd: "/Users/me/Code"),
            .loadSession(requestID: "r2", conversationID: "c1", sessionID: "s1", cwd: "/Users/me/Code"),
            .conversationRename(requestID: "r4", conversationID: "c1", title: "Renamed"),
            .conversationDelete(requestID: "r5", conversationID: "c1"),
            .listSessions(requestID: "r0", cwd: nil),
            .sessionReady(requestID: "r1", conversationID: "c1", sessionID: "s1"),
            .sessionLoaded(requestID: "r2", conversationID: "c1", sessionID: "s1"),
            .sessionLoadFailed(requestID: "r2", conversationID: "c1", sessionID: "s1", message: "not found"),
            .sessionHistory(conversationID: "c1", sessionID: "s1", role: "assistant", text: "Hello"),
            .sessionList(requestID: "r0", sessions: [["session_id": "s1", "cwd": "/Users/me/Code"]]),
            .cancel(requestID: "r3", sessionID: "s1")
        ]

        for message in messages {
            #expect(try PeppaIPCCodec.decodeLine(PeppaIPCCodec.encode(message: message)) == message)
        }
    }
}
