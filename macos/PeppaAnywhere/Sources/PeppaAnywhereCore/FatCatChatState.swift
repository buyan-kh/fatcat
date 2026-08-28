import Foundation

public struct FatCatTranscriptMessage: Codable, Equatable, Identifiable, Sendable {
    public enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
    }

    public let id: UUID
    public let role: Role
    public var text: String
    public var requestID: String?
    public var isStreaming: Bool
    public var errorMessage: String?

    public init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        requestID: String? = nil,
        isStreaming: Bool = false,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.requestID = requestID
        self.isStreaming = isStreaming
        self.errorMessage = errorMessage
    }
}

public struct FatCatTranscriptState: Equatable, Sendable {
    public private(set) var messages: [FatCatTranscriptMessage] = []

    public init(messages: [FatCatTranscriptMessage] = []) {
        self.messages = messages
    }

    public mutating func appendUser(_ text: String) {
        messages.append(FatCatTranscriptMessage(role: .user, text: text))
    }

    @discardableResult
    public mutating func beginAssistant(requestID: String) -> UUID {
        if let index = messages.lastIndex(where: { $0.role == .assistant && $0.requestID == requestID }) {
            messages[index].isStreaming = true
            return messages[index].id
        }
        let message = FatCatTranscriptMessage(role: .assistant, text: "", requestID: requestID, isStreaming: true)
        messages.append(message)
        return message.id
    }

    public mutating func appendAssistantDelta(requestID: String, text: String) {
        guard let index = messages.lastIndex(where: { $0.role == .assistant && $0.requestID == requestID }) else {
            _ = beginAssistant(requestID: requestID)
            messages[messages.count - 1].text = text
            return
        }
        messages[index].text += text
        messages[index].isStreaming = true
    }

    public mutating func completeAssistant(requestID: String) {
        guard let index = messages.lastIndex(where: { $0.requestID == requestID }) else { return }
        messages[index].isStreaming = false
    }

    public mutating func failAssistant(requestID: String, message: String) {
        guard let index = messages.lastIndex(where: { $0.requestID == requestID }) else { return }
        messages[index].isStreaming = false
        messages[index].errorMessage = message
    }

    public mutating func appendSystem(_ text: String) {
        messages.append(FatCatTranscriptMessage(role: .system, text: text))
    }
}

public struct ChatScrollState: Equatable, Sendable {
    public private(set) var isNearBottom = true
    public private(set) var shouldAutoScroll = true
    public private(set) var hasUnreadBelow = false
    public private(set) var latestMessageRevision = 0

    public init() {}

    public mutating func noteContentChanged() {
        latestMessageRevision += 1
        if !shouldAutoScroll { hasUnreadBelow = true }
    }

    public mutating func noteStreamingChanged() {
        latestMessageRevision += 1
        if !shouldAutoScroll { hasUnreadBelow = true }
    }

    public mutating func updateViewport(isNearBottom: Bool) {
        self.isNearBottom = isNearBottom
        shouldAutoScroll = isNearBottom
        if isNearBottom { hasUnreadBelow = false }
    }

    public mutating func jumpToLatest() {
        isNearBottom = true
        shouldAutoScroll = true
        hasUnreadBelow = false
    }

    public mutating func opened() {
        jumpToLatest()
    }
}

public struct ComposerModifier: OptionSet, Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let shift = ComposerModifier(rawValue: 1 << 0)
    public static let command = ComposerModifier(rawValue: 1 << 1)
}

public enum ComposerKey: Equatable, Sendable {
    case `return`
    case escape
    case other
}

public enum ComposerAction: Equatable, Sendable {
    case send
    case insertNewline
    case dismiss
    case none
}

public enum ComposerKeyBehavior {
    public static func action(key: ComposerKey, modifiers: ComposerModifier, hasText: Bool) -> ComposerAction {
        switch key {
        case .return:
            if modifiers.contains(.shift) { return .insertNewline }
            return hasText ? .send : .none
        case .escape:
            return .dismiss
        case .other:
            return .none
        }
    }
}

public struct FatCatRetryState: Equatable, Sendable {
    public private(set) var promptForRetry: String?

    public init(promptForRetry: String? = nil) {
        self.promptForRetry = promptForRetry
    }

    public mutating func record(_ prompt: String) {
        let normalized = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalized.isEmpty { promptForRetry = normalized }
    }

    public mutating func clear() {
        promptForRetry = nil
    }
}

public struct FatCatConversationRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var hermesSessionID: String?
    public var title: String
    public let createdAt: Date
    public var updatedAt: Date
    public var lastPreview: String
    public var workspacePath: String

    public init(
        id: String = UUID().uuidString,
        hermesSessionID: String? = nil,
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastPreview: String = "",
        workspacePath: String
    ) {
        self.id = id
        self.hermesSessionID = hermesSessionID
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastPreview = lastPreview
        self.workspacePath = workspacePath
    }
}

public enum FatCatSessionResolution: Equatable, Sendable {
    case create
    case load(sessionID: String)
    case showFailure(sessionID: String)

    public static func forRecord(_ record: FatCatConversationRecord?) -> Self {
        guard let record, let sessionID = record.hermesSessionID, !sessionID.isEmpty else { return .create }
        return .load(sessionID: sessionID)
    }

    public static func failedResume(for record: FatCatConversationRecord) -> Self {
        guard let sessionID = record.hermesSessionID, !sessionID.isEmpty else { return .create }
        return .showFailure(sessionID: sessionID)
    }
}

public enum FatCatConversationStoreError: Error, Equatable, Sendable {
    case conversationNotFound
}

public final class FatCatConversationStore: @unchecked Sendable {
    private struct Document: Codable {
        var selectedID: String?
        var records: [FatCatConversationRecord]
    }

    public private(set) var records: [FatCatConversationRecord]
    public private(set) var selectedID: String?
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let lock = NSLock()

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL), !data.isEmpty {
            let document = try decoder.decode(Document.self, from: data)
            records = document.records
            selectedID = document.selectedID
        } else {
            records = []
            selectedID = nil
        }
    }

    @discardableResult
    public func create(title: String, workspacePath: String) throws -> FatCatConversationRecord {
        let now = Date()
        let record = FatCatConversationRecord(title: title, createdAt: now, updatedAt: now, workspacePath: workspacePath)
        lock.lock()
        records.insert(record, at: 0)
        selectedID = record.id
        defer { lock.unlock() }
        try persistLocked()
        return record
    }

    public func select(recordID: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard records.contains(where: { $0.id == recordID }) else { throw FatCatConversationStoreError.conversationNotFound }
        selectedID = recordID
        try persistLocked()
    }

    public func attachHermesSession(_ sessionID: String, to recordID: String) throws {
        try mutate(recordID: recordID) { record in record.hermesSessionID = sessionID }
    }

    public func update(recordID: String, title: String? = nil, preview: String? = nil) throws {
        try mutate(recordID: recordID) { record in
            if let title { record.title = title }
            if let preview { record.lastPreview = preview }
        }
    }

    public func delete(recordID: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard records.contains(where: { $0.id == recordID }) else { throw FatCatConversationStoreError.conversationNotFound }
        records.removeAll { $0.id == recordID }
        if selectedID == recordID { selectedID = records.first?.id }
        try persistLocked()
    }

    public func search(_ query: String) -> [FatCatConversationRecord] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return records }
        return records.filter {
            $0.title.lowercased().contains(normalized) || $0.lastPreview.lowercased().contains(normalized)
        }
    }

    private func mutate(recordID: String, _ mutation: (inout FatCatConversationRecord) -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { throw FatCatConversationStoreError.conversationNotFound }
        mutation(&records[index])
        records[index].updatedAt = Date()
        try persistLocked()
    }

    private func persistLocked() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(Document(selectedID: selectedID, records: records))
        try data.write(to: fileURL, options: .atomic)
    }
}
