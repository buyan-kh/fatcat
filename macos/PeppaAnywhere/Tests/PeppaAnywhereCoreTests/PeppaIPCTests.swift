import Foundation
import Testing
@testable import PeppaAnywhereCore

struct PeppaIPCTests {
    @Test func encodesTypedMessagesAsOneNewlineDelimitedRecord() throws {
        let message = PeppaIPCMessage.userMessage(
            requestID: "request-1",
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

    @Test func roundTripsConversationLifecycleAndCancellation() throws {
        let messages: [PeppaIPCMessage] = [
            .newSession(requestID: "r1", conversationID: "c1", cwd: "/Users/me/Code"),
            .loadSession(requestID: "r2", conversationID: "c1", sessionID: "s1", cwd: "/Users/me/Code"),
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
