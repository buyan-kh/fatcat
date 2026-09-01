import Foundation
import Testing
@testable import FatCatCore

struct FatCatChatStateTests {
    @Test func streamingChunksAppendToOneStableAssistantMessage() {
        var transcript = FatCatTranscriptState()
        transcript.appendUser("Fix this")
        let assistantID = transcript.beginAssistant(requestID: "request-1")

        transcript.appendAssistantDelta(requestID: "request-1", text: "First")
        transcript.appendAssistantDelta(requestID: "request-1", text: " second")

        #expect(transcript.messages.count == 2)
        #expect(transcript.messages[1].id == assistantID)
        #expect(transcript.messages[1].text == "First second")
        #expect(transcript.messages[1].isStreaming)
    }

    @Test func partialAssistantOutputRemainsAfterFailure() {
        var transcript = FatCatTranscriptState()
        _ = transcript.beginAssistant(requestID: "request-1")
        transcript.appendAssistantDelta(requestID: "request-1", text: "Partial")

        transcript.failAssistant(requestID: "request-1", message: "Connection lost")

        #expect(transcript.messages.last?.text == "Partial")
        #expect(transcript.messages.last?.errorMessage == "Connection lost")
        #expect(transcript.messages.last?.isStreaming == false)
    }

    @Test func scrollStateKeepsUnreadWhenUserReadsOlderMessages() {
        var state = ChatScrollState()
        state.updateViewport(isNearBottom: false)
        state.noteContentChanged()

        #expect(state.shouldAutoScroll == false)
        #expect(state.hasUnreadBelow)

        state.jumpToLatest()
        #expect(state.shouldAutoScroll)
        #expect(state.isNearBottom)
        #expect(state.hasUnreadBelow == false)
    }

    @Test func scrollStateAutoScrollsNewAndStreamingContentAtBottom() {
        var state = ChatScrollState()
        let firstRevision = state.latestMessageRevision
        state.noteContentChanged()
        state.noteStreamingChanged()

        #expect(state.shouldAutoScroll)
        #expect(state.latestMessageRevision > firstRevision)
        #expect(state.hasUnreadBelow == false)
    }

    @Test func contentGrowthDoesNotLookLikeAUserScroll() {
        var state = ChatScrollState()
        state.noteStreamingChanged()
        state.updateViewport(isNearBottom: false)

        #expect(state.shouldAutoScroll)

        state.updateViewport(isNearBottom: false)
        #expect(state.shouldAutoScroll == false)
    }

    @Test func openingChatReturnsToLatest() {
        var state = ChatScrollState()
        state.updateViewport(isNearBottom: false)
        state.opened()

        #expect(state.shouldAutoScroll)
        #expect(state.hasUnreadBelow == false)
    }

    @Test func composerKeysDistinguishSendFromNewline() {
        #expect(ComposerKeyBehavior.action(key: .return, modifiers: [], hasText: true) == .send)
        #expect(ComposerKeyBehavior.action(key: .return, modifiers: [.shift], hasText: true) == .insertNewline)
        #expect(ComposerKeyBehavior.action(key: .return, modifiers: [.command], hasText: true) == .send)
        #expect(ComposerKeyBehavior.action(key: .escape, modifiers: [], hasText: false) == .dismiss)
        #expect(ComposerKeyBehavior.action(key: .return, modifiers: [], hasText: false) == .none)
    }

    @Test func conversationStorePersistsAndSearchesMetadataOnly() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = try FatCatConversationStore(fileURL: url)
        let record = try store.create(title: "Debug Xcode", workspacePath: "/Users/me/Code")
        try store.update(recordID: record.id, preview: "Cannot find ViewModel")
        try store.select(recordID: record.id)

        let reopened = try FatCatConversationStore(fileURL: url)
        #expect(reopened.selectedID == record.id)
        #expect(reopened.search("viewmodel").first?.id == record.id)
        #expect(reopened.records.first?.hermesSessionID == nil)
    }

    @Test func conversationSessionIsReusedAndNewChatIsDistinct() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try FatCatConversationStore(fileURL: url)
        let first = try store.create(title: "First", workspacePath: "/Users/me")
        try store.attachHermesSession("hermes-1", to: first.id)
        #expect(store.records.first?.hermesSessionID == "hermes-1")

        let second = try store.create(title: "Second", workspacePath: "/Users/me")
        #expect(second.id != first.id)
        #expect(second.hermesSessionID == nil)
    }

    @Test func failedResumeDoesNotReplaceSavedSession() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try FatCatConversationStore(fileURL: url)
        let record = try store.create(title: "Resume", workspacePath: "/Users/me")
        try store.attachHermesSession("saved-session", to: record.id)

        #expect(FatCatSessionResolution.forRecord(store.records[0]) == .load(sessionID: "saved-session"))
        #expect(FatCatSessionResolution.failedResume(for: store.records[0]) == .showFailure(sessionID: "saved-session"))
    }

    @Test func conversationSelectionKeepsAValidLocalChoice() {
        let selected = FatCatConversationSelection.resolve(
            localID: "native-chat",
            sharedID: "electron-chat",
            availableIDs: ["electron-chat", "native-chat"]
        )

        #expect(selected == "native-chat")
    }

    @Test func conversationSelectionFallsBackToAValidSharedChoice() {
        let selected = FatCatConversationSelection.resolve(
            localID: "deleted-chat",
            sharedID: "electron-chat",
            availableIDs: ["electron-chat", "other-chat"]
        )

        #expect(selected == "electron-chat")
    }

    @Test func conversationSelectionUsesFirstRecordWhenBothChoicesAreInvalid() {
        let selected = FatCatConversationSelection.resolve(
            localID: "deleted-chat",
            sharedID: "missing-chat",
            availableIDs: ["first-chat", "second-chat"]
        )

        #expect(selected == "first-chat")
    }

    @Test func conversationSelectionClearsForAnEmptySnapshot() {
        let selected = FatCatConversationSelection.resolve(
            localID: "native-chat",
            sharedID: "electron-chat",
            availableIDs: []
        )

        #expect(selected == nil)
    }

    @Test func sharedSnapshotReplacesTheLocalConversationCache() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        defer { try? FileManager.default.removeItem(at: url) }
        let store = try FatCatConversationStore(fileURL: url)
        _ = try store.create(title: "Stale", workspacePath: "/tmp")
        let shared = FatCatConversationRecord(id: "c1", hermesSessionID: "s1", title: "Shared", workspacePath: "/tmp/shared")

        try store.replace(records: [shared], selectedID: "c1")

        let reopened = try FatCatConversationStore(fileURL: url)
        #expect(reopened.selectedID == "c1")
        #expect(reopened.records == [shared])
    }

    @Test func retryStateKeepsTheMostRecentlySubmittedPrompt() {
        var retry = FatCatRetryState()
        #expect(retry.promptForRetry == nil)

        retry.record("Fix the compiler error")
        retry.record("Now explain the fix")

        #expect(retry.promptForRetry == "Now explain the fix")
        retry.clear()
        #expect(retry.promptForRetry == nil)
    }
}
