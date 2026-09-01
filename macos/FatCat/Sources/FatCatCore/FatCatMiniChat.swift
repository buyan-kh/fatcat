import Foundation

public struct FatCatMiniChatState: Equatable, Sendable {
    public private(set) var isPresented = false
    public private(set) var latestUserText: String?
    public private(set) var latestAssistantText: String?
    public private(set) var activeRequestID: String?
    public private(set) var connectionDetail = "Connecting to FatCat Agent…"

    public init() {}

    public mutating func toggle() { isPresented.toggle() }
    public mutating func close() { isPresented = false }

    public mutating func appendUser(_ text: String, requestID: String) {
        latestUserText = text
        latestAssistantText = nil
        activeRequestID = requestID
    }

    public mutating func appendAssistant(_ text: String, requestID: String) {
        guard activeRequestID == nil || activeRequestID == requestID else { return }
        activeRequestID = requestID
        latestAssistantText = (latestAssistantText ?? "") + text
    }

    public mutating func complete(requestID: String) {
        if activeRequestID == requestID { activeRequestID = nil }
    }

    public mutating func disconnected() {
        connectionDetail = "FatCat Agent disconnected"
        activeRequestID = nil
    }
}
