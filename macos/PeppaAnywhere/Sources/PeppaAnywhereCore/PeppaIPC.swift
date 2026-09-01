import Foundation

public enum PeppaAgentState: String, Codable, Equatable, Sendable {
    case connecting
    case ready
    case sending
    case idle
    case listening
    case thinking
    case streaming
    case stopping
    case completed
    case working
    case waitingForApproval = "waiting_for_approval"
    case verifying
    case failed
    case disconnected
    case error
}

public struct FatCatIPCMessageRecord: Codable, Equatable, Sendable {
    public let id: String
    public let role: String
    public let text: String

    public init(id: String, role: String, text: String) {
        self.id = id
        self.role = role
        self.text = text
    }
}

public struct FatCatIPCConversationRecord: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let workspacePath: String
    public let sessionID: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case workspacePath = "workspace_path"
        case sessionID = "session_id"
    }

    public init(id: String, title: String, workspacePath: String, sessionID: String?) {
        self.id = id
        self.title = title
        self.workspacePath = workspacePath
        self.sessionID = sessionID
    }
}

public struct FatCatHermesEvent: Codable, Equatable, Sendable {
    public let eventID: String
    public let kind: String
    public let sessionID: String
    public let requestID: String?
    public let summary: String
    public let details: [String: String]

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case kind
        case sessionID = "session_id"
        case requestID = "request_id"
        case summary, details
    }

    public init(eventID: String, kind: String, sessionID: String, requestID: String?, summary: String, details: [String: String]) {
        self.eventID = eventID
        self.kind = kind
        self.sessionID = sessionID
        self.requestID = requestID
        self.summary = summary
        self.details = details
    }
}

public enum PeppaIPCMessage: Equatable, Sendable {
    case hello
    case clientHello(client: String)
    case helloAck(agentVersion: String)
    case petClicked(eventID: String, petID: String, conversationID: String?)
    case conversationRename(requestID: String, conversationID: String, title: String)
    case conversationDelete(requestID: String, conversationID: String)
    case conversationSnapshot(selectedID: String?, records: [FatCatIPCConversationRecord])
    case messageAdded(conversationID: String, sessionID: String, message: FatCatIPCMessageRecord)
    case newSession(requestID: String, conversationID: String, cwd: String)
    case loadSession(requestID: String, conversationID: String, sessionID: String, cwd: String)
    case listSessions(requestID: String, cwd: String?)
    case sessionReady(requestID: String, conversationID: String, sessionID: String)
    case sessionLoaded(requestID: String, conversationID: String, sessionID: String)
    case sessionLoadFailed(requestID: String, conversationID: String, sessionID: String, message: String)
    case sessionHistory(conversationID: String, sessionID: String, role: String, text: String)
    case sessionList(requestID: String, sessions: [[String: String]])
    case userMessage(requestID: String, conversationID: String, sessionID: String, text: String)
    case cancel(requestID: String, sessionID: String)
    case observation(requestID: String?, activeApp: String, window: String?, visibleText: [String], confidence: Double)
    case plan(requestID: String, sessionID: String, steps: [String])
    case toolCall(requestID: String, name: String, arguments: [String: String])
    case providerStatus(providerID: String, authenticated: Bool, detail: String)
    case providerInventory(requestID: String)
    case providerModels(requestID: String, providerID: String, refresh: Bool)
    case providerSetDefault(requestID: String, providerID: String, model: String)
    case providerSetCredentialRef(requestID: String, providerID: String, credentialRef: String)
    case providerSetBaseURL(requestID: String, providerID: String, baseURL: String)
    case providerValidate(requestID: String, providerID: String, model: String)
    case providerInventoryResult(requestID: String, providers: [[String: String]])
    case providerModelsResult(requestID: String, providerID: String, models: [String])
    case providerConfigured(requestID: String, operation: String, provider: String, model: String?, credentialRef: String?)
    case providerValidationResult(requestID: String, provider: String, model: String, usable: Bool, detail: String)
    case assistantDelta(requestID: String, sessionID: String, text: String)
    case state(PeppaAgentState)
    case sessionState(PeppaAgentState, sessionID: String, requestID: String?)
    case proposedAction(requestID: String, action: String, risk: String, reason: String)
    case permissionRequest(requestID: String, action: String, risk: String, reason: String)
    case actionResult(requestID: String, success: Bool, detail: String)
    case verificationResult(requestID: String, success: Bool, detail: String)
    case memoryUpdate(sessionID: String, detail: String)
    case hermesEvent(FatCatHermesEvent)
    case error(requestID: String?, message: String)
    case shutdown
    case shutdownAck
}

public enum PeppaIPCError: Error, Equatable, Sendable {
    case malformed(String)
    case unsupportedVersion(Int)
    case unsupportedType(String)
    case credentialField(String)
}

public enum PeppaIPCCodec {
    public static func encode(message: PeppaIPCMessage) throws -> Data {
        let object = try object(for: message)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return data + Data([0x0A])
    }

    public static func decodeLine(_ line: String) throws -> PeppaIPCMessage {
        try decodeLine(Data(line.utf8))
    }

    public static func decodeLine(_ line: Data) throws -> PeppaIPCMessage {
        let trimmed = line.drop { $0 == 0x0A || $0 == 0x0D || $0 == 0x20 || $0 == 0x09 }
        guard !trimmed.isEmpty else { throw PeppaIPCError.malformed("empty line") }
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: Data(trimmed))
        } catch {
            throw PeppaIPCError.malformed("invalid JSON")
        }
        guard let dictionary = object as? [String: Any] else { throw PeppaIPCError.malformed("message must be an object") }
        try rejectCredentials(in: dictionary)
        guard let version = dictionary["version"] as? Int else { throw PeppaIPCError.malformed("missing version") }
        if version == 2 {
            guard let kind = dictionary["kind"] as? String,
                  let eventID = dictionary["event_id"] as? String,
                  let sessionID = dictionary["session_id"] as? String,
                  let summary = dictionary["summary"] as? String,
                  let rawDetails = dictionary["details"] as? [String: Any] else {
                throw PeppaIPCError.malformed("invalid Hermes event")
            }
            let details = try rawDetails.reduce(into: [String: String]()) { result, entry in
                let (key, value) = entry
                if let string = value as? String {
                    result[key] = string
                } else if (value is [Any] || value is [String: Any]), JSONSerialization.isValidJSONObject(value) {
                    let encoded = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
                    result[key] = String(decoding: encoded, as: UTF8.self)
                } else {
                    result[key] = String(describing: value)
                }
            }
            return .hermesEvent(FatCatHermesEvent(
                eventID: eventID,
                kind: kind,
                sessionID: sessionID,
                requestID: dictionary["request_id"] as? String,
                summary: summary,
                details: details,
            ))
        }
        guard version == 1 else { throw PeppaIPCError.unsupportedVersion(version) }
        guard let type = dictionary["type"] as? String else { throw PeppaIPCError.malformed("missing type") }
        func string(_ key: String) throws -> String {
            guard let value = dictionary[key] as? String else { throw PeppaIPCError.malformed("missing \(key)") }
            return value
        }
        func bool(_ key: String) throws -> Bool {
            guard let value = dictionary[key] as? Bool else { throw PeppaIPCError.malformed("missing \(key)") }
            return value
        }
        func optionalString(_ key: String) -> String? {
            dictionary[key] as? String
        }
        switch type {
        case "hello":
            if let client = dictionary["client"] as? String { return .clientHello(client: client) }
            return .hello
        case "hello_ack": return .helloAck(agentVersion: try string("agent_version"))
        case "pet_clicked": return .petClicked(eventID: try string("event_id"), petID: try string("pet_id"), conversationID: optionalString("conversation_id"))
        case "conversation_rename": return .conversationRename(requestID: try string("request_id"), conversationID: try string("conversation_id"), title: try string("title"))
        case "conversation_delete": return .conversationDelete(requestID: try string("request_id"), conversationID: try string("conversation_id"))
        case "conversation_snapshot":
            guard let recordsValue = dictionary["records"] else { throw PeppaIPCError.malformed("missing records") }
            let records: [FatCatIPCConversationRecord] = try decodeValue(recordsValue, field: "records")
            return .conversationSnapshot(selectedID: optionalString("selected_id"), records: records)
        case "message_added":
            guard let messageValue = dictionary["message"] else { throw PeppaIPCError.malformed("missing message") }
            let message: FatCatIPCMessageRecord = try decodeValue(messageValue, field: "message")
            return .messageAdded(conversationID: try string("conversation_id"), sessionID: try string("session_id"), message: message)
        case "new_session": return .newSession(requestID: try string("request_id"), conversationID: try string("conversation_id"), cwd: try string("cwd"))
        case "load_session": return .loadSession(requestID: try string("request_id"), conversationID: try string("conversation_id"), sessionID: try string("session_id"), cwd: try string("cwd"))
        case "list_sessions": return .listSessions(requestID: try string("request_id"), cwd: dictionary["cwd"] as? String)
        case "session_ready": return .sessionReady(requestID: try string("request_id"), conversationID: try string("conversation_id"), sessionID: try string("session_id"))
        case "session_loaded": return .sessionLoaded(requestID: try string("request_id"), conversationID: try string("conversation_id"), sessionID: try string("session_id"))
        case "session_load_failed": return .sessionLoadFailed(requestID: try string("request_id"), conversationID: try string("conversation_id"), sessionID: try string("session_id"), message: try string("message"))
        case "session_history": return .sessionHistory(conversationID: try string("conversation_id"), sessionID: try string("session_id"), role: try string("role"), text: try string("text"))
        case "session_list":
            guard let sessions = dictionary["sessions"] as? [[String: String]] else { throw PeppaIPCError.malformed("invalid session list") }
            return .sessionList(requestID: try string("request_id"), sessions: sessions)
        case "user_message": return .userMessage(requestID: try string("request_id"), conversationID: try string("conversation_id"), sessionID: try string("session_id"), text: try string("text"))
        case "cancel": return .cancel(requestID: try string("request_id"), sessionID: try string("session_id"))
        case "assistant_delta": return .assistantDelta(requestID: try string("request_id"), sessionID: try string("session_id"), text: try string("text"))
        case "plan":
            guard let steps = dictionary["steps"] as? [String] else { throw PeppaIPCError.malformed("invalid plan") }
            return .plan(requestID: try string("request_id"), sessionID: try string("session_id"), steps: steps)
        case "tool_call":
            guard let arguments = dictionary["arguments"] as? [String: String] else { throw PeppaIPCError.malformed("invalid tool call") }
            return .toolCall(requestID: try string("request_id"), name: try string("name"), arguments: arguments)
        case "provider_status": return .providerStatus(providerID: try string("provider_id"), authenticated: try bool("authenticated"), detail: try string("detail"))
        case "provider_inventory": return .providerInventory(requestID: try string("request_id"))
        case "provider_models": return .providerModels(requestID: try string("request_id"), providerID: try string("provider_id"), refresh: try bool("refresh"))
        case "provider_set_default": return .providerSetDefault(requestID: try string("request_id"), providerID: try string("provider_id"), model: try string("model"))
        case "provider_set_credential_ref": return .providerSetCredentialRef(requestID: try string("request_id"), providerID: try string("provider_id"), credentialRef: try string("credential_ref"))
        case "provider_set_base_url": return .providerSetBaseURL(requestID: try string("request_id"), providerID: try string("provider_id"), baseURL: try string("base_url"))
        case "provider_validate": return .providerValidate(requestID: try string("request_id"), providerID: try string("provider_id"), model: try string("model"))
        case "provider_inventory_result":
            guard let providers = dictionary["providers"] as? [[String: String]] else { throw PeppaIPCError.malformed("invalid provider inventory") }
            return .providerInventoryResult(requestID: try string("request_id"), providers: providers)
        case "provider_models_result":
            guard let models = dictionary["models"] as? [String] else { throw PeppaIPCError.malformed("invalid provider models") }
            return .providerModelsResult(requestID: try string("request_id"), providerID: try string("provider_id"), models: models)
        case "provider_configured":
            return .providerConfigured(requestID: try string("request_id"), operation: try string("operation"), provider: try string("provider"), model: optionalString("model"), credentialRef: optionalString("credential_ref"))
        case "provider_validation_result":
            return .providerValidationResult(requestID: try string("request_id"), provider: try string("provider"), model: try string("model"), usable: try bool("usable"), detail: try string("detail"))
        case "state":
            guard let state = PeppaAgentState(rawValue: try string("state")) else { throw PeppaIPCError.malformed("unknown state") }
            if let sessionID = dictionary["session_id"] as? String {
                return .sessionState(state, sessionID: sessionID, requestID: dictionary["request_id"] as? String)
            }
            return .state(state)
        case "observation":
            guard let activeApp = dictionary["active_app"] as? String,
                  let visibleText = dictionary["visible_text"] as? [String],
                  let confidence = dictionary["confidence"] as? Double else { throw PeppaIPCError.malformed("invalid observation") }
            return .observation(requestID: dictionary["request_id"] as? String, activeApp: activeApp, window: dictionary["window"] as? String, visibleText: visibleText, confidence: confidence)
        case "proposed_action": return .proposedAction(requestID: try string("request_id"), action: try string("action"), risk: try string("risk"), reason: try string("reason"))
        case "permission_request": return .permissionRequest(requestID: try string("request_id"), action: try string("action"), risk: try string("risk"), reason: try string("reason"))
        case "action_result": return .actionResult(requestID: try string("request_id"), success: try bool("success"), detail: try string("detail"))
        case "verification_result": return .verificationResult(requestID: try string("request_id"), success: try bool("success"), detail: try string("detail"))
        case "memory_update": return .memoryUpdate(sessionID: try string("session_id"), detail: try string("detail"))
        case "error": return .error(requestID: dictionary["request_id"] as? String, message: try string("message"))
        case "shutdown": return .shutdown
        case "shutdown_ack": return .shutdownAck
        default: throw PeppaIPCError.unsupportedType(type)
        }
    }

    private static func object(for message: PeppaIPCMessage) throws -> [String: Any] {
        switch message {
        case .hello: return ["version": 1, "type": "hello"]
        case let .clientHello(client): return ["version": 1, "type": "hello", "client": client]
        case let .helloAck(agentVersion): return ["version": 1, "type": "hello_ack", "agent_version": agentVersion]
        case let .petClicked(eventID, petID, conversationID): return ["version": 1, "type": "pet_clicked", "event_id": eventID, "pet_id": petID, "conversation_id": conversationID ?? NSNull()]
        case let .conversationRename(requestID, conversationID, title): return ["version": 1, "type": "conversation_rename", "request_id": requestID, "conversation_id": conversationID, "title": title]
        case let .conversationDelete(requestID, conversationID): return ["version": 1, "type": "conversation_delete", "request_id": requestID, "conversation_id": conversationID]
        case let .conversationSnapshot(selectedID, records): return ["version": 1, "type": "conversation_snapshot", "selected_id": selectedID ?? NSNull(), "records": try encodeValue(records)]
        case let .messageAdded(conversationID, sessionID, message): return ["version": 1, "type": "message_added", "conversation_id": conversationID, "session_id": sessionID, "message": try encodeValue(message)]
        case let .newSession(requestID, conversationID, cwd): return ["version": 1, "type": "new_session", "request_id": requestID, "conversation_id": conversationID, "cwd": cwd]
        case let .loadSession(requestID, conversationID, sessionID, cwd): return ["version": 1, "type": "load_session", "request_id": requestID, "conversation_id": conversationID, "session_id": sessionID, "cwd": cwd]
        case let .listSessions(requestID, cwd): return ["version": 1, "type": "list_sessions", "request_id": requestID, "cwd": cwd ?? NSNull()]
        case let .sessionReady(requestID, conversationID, sessionID): return ["version": 1, "type": "session_ready", "request_id": requestID, "conversation_id": conversationID, "session_id": sessionID]
        case let .sessionLoaded(requestID, conversationID, sessionID): return ["version": 1, "type": "session_loaded", "request_id": requestID, "conversation_id": conversationID, "session_id": sessionID]
        case let .sessionLoadFailed(requestID, conversationID, sessionID, message): return ["version": 1, "type": "session_load_failed", "request_id": requestID, "conversation_id": conversationID, "session_id": sessionID, "message": message]
        case let .sessionHistory(conversationID, sessionID, role, text): return ["version": 1, "type": "session_history", "conversation_id": conversationID, "session_id": sessionID, "role": role, "text": text]
        case let .sessionList(requestID, sessions): return ["version": 1, "type": "session_list", "request_id": requestID, "sessions": sessions]
        case let .userMessage(requestID, conversationID, sessionID, text): return ["version": 1, "type": "user_message", "request_id": requestID, "conversation_id": conversationID, "session_id": sessionID, "text": text]
        case let .cancel(requestID, sessionID): return ["version": 1, "type": "cancel", "request_id": requestID, "session_id": sessionID]
        case let .observation(requestID, activeApp, window, visibleText, confidence): return ["version": 1, "type": "observation", "request_id": requestID ?? NSNull(), "active_app": activeApp, "window": window ?? NSNull(), "visible_text": visibleText, "confidence": confidence]
        case let .plan(requestID, sessionID, steps): return ["version": 1, "type": "plan", "request_id": requestID, "session_id": sessionID, "steps": steps]
        case let .toolCall(requestID, name, arguments): return ["version": 1, "type": "tool_call", "request_id": requestID, "name": name, "arguments": arguments]
        case let .providerStatus(providerID, authenticated, detail): return ["version": 1, "type": "provider_status", "provider_id": providerID, "authenticated": authenticated, "detail": detail]
        case let .providerInventory(requestID): return ["version": 1, "type": "provider_inventory", "request_id": requestID]
        case let .providerModels(requestID, providerID, refresh): return ["version": 1, "type": "provider_models", "request_id": requestID, "provider_id": providerID, "refresh": refresh]
        case let .providerSetDefault(requestID, providerID, model): return ["version": 1, "type": "provider_set_default", "request_id": requestID, "provider_id": providerID, "model": model]
        case let .providerSetCredentialRef(requestID, providerID, credentialRef): return ["version": 1, "type": "provider_set_credential_ref", "request_id": requestID, "provider_id": providerID, "credential_ref": credentialRef]
        case let .providerSetBaseURL(requestID, providerID, baseURL): return ["version": 1, "type": "provider_set_base_url", "request_id": requestID, "provider_id": providerID, "base_url": baseURL]
        case let .providerValidate(requestID, providerID, model): return ["version": 1, "type": "provider_validate", "request_id": requestID, "provider_id": providerID, "model": model]
        case let .providerInventoryResult(requestID, providers): return ["version": 1, "type": "provider_inventory_result", "request_id": requestID, "providers": providers]
        case let .providerModelsResult(requestID, providerID, models): return ["version": 1, "type": "provider_models_result", "request_id": requestID, "provider_id": providerID, "models": models]
        case let .providerConfigured(requestID, operation, provider, model, credentialRef): return ["version": 1, "type": "provider_configured", "request_id": requestID, "operation": operation, "provider": provider, "model": model ?? NSNull(), "credential_ref": credentialRef ?? NSNull()]
        case let .providerValidationResult(requestID, provider, model, usable, detail): return ["version": 1, "type": "provider_validation_result", "request_id": requestID, "provider": provider, "model": model, "usable": usable, "detail": detail]
        case let .assistantDelta(requestID, sessionID, text): return ["version": 1, "type": "assistant_delta", "request_id": requestID, "session_id": sessionID, "text": text]
        case let .state(state): return ["version": 1, "type": "state", "state": state.rawValue]
        case let .sessionState(state, sessionID, requestID): return ["version": 1, "type": "state", "state": state.rawValue, "session_id": sessionID, "request_id": requestID ?? NSNull()]
        case let .proposedAction(requestID, action, risk, reason): return ["version": 1, "type": "proposed_action", "request_id": requestID, "action": action, "risk": risk, "reason": reason]
        case let .permissionRequest(requestID, action, risk, reason): return ["version": 1, "type": "permission_request", "request_id": requestID, "action": action, "risk": risk, "reason": reason]
        case let .actionResult(requestID, success, detail): return ["version": 1, "type": "action_result", "request_id": requestID, "success": success, "detail": detail]
        case let .verificationResult(requestID, success, detail): return ["version": 1, "type": "verification_result", "request_id": requestID, "success": success, "detail": detail]
        case let .memoryUpdate(sessionID, detail): return ["version": 1, "type": "memory_update", "session_id": sessionID, "detail": detail]
        case let .hermesEvent(event):
            var value: [String: Any] = [
                "version": 2,
                "event_id": event.eventID,
                "kind": event.kind,
                "session_id": event.sessionID,
                "summary": event.summary,
                "details": event.details,
            ]
            if let requestID = event.requestID { value["request_id"] = requestID }
            return value
        case let .error(requestID, message): return ["version": 1, "type": "error", "request_id": requestID ?? NSNull(), "message": message]
        case .shutdown: return ["version": 1, "type": "shutdown"]
        case .shutdownAck: return ["version": 1, "type": "shutdown_ack"]
        }
    }

    private static func rejectCredentials(in value: [String: Any], path: String = "") throws {
        let forbidden = ["api_key", "access_token", "refresh_token", "cookie", "password", "secret"]
        for (key, child) in value {
            if forbidden.contains(key.lowercased()) { throw PeppaIPCError.credentialField(path + key) }
            if let nested = child as? [String: Any] { try rejectCredentials(in: nested, path: path + key + ".") }
            if let array = child as? [[String: Any]] { for item in array { try rejectCredentials(in: item, path: path + key + ".") } }
        }
    }

    private static func decodeValue<T: Decodable>(_ value: Any, field: String) throws -> T {
        do {
            let data = try JSONSerialization.data(withJSONObject: value)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw PeppaIPCError.malformed("invalid \(field)")
        }
    }

    private static func encodeValue<T: Encodable>(_ value: T) throws -> Any {
        let data = try JSONEncoder().encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }
}
