import Testing
@testable import PeppaAnywhereCore

struct FatCatMiniChatTests {
    @Test func petClickTogglesAndCloseAlwaysHides() {
        var state = FatCatMiniChatState()
        state.toggle()
        #expect(state.isPresented)
        state.toggle()
        #expect(!state.isPresented)
        state.toggle()
        state.close()
        #expect(!state.isPresented)
    }

    @Test func keepsOnlyTheLatestExchangeAndStreamsOneReply() {
        var state = FatCatMiniChatState()
        state.appendUser("First", requestID: "r1")
        state.appendAssistant("Old", requestID: "r1")
        state.complete(requestID: "r1")
        state.appendUser("Latest", requestID: "r2")
        state.appendAssistant("Hello ", requestID: "r2")
        state.appendAssistant("back", requestID: "r2")

        #expect(state.latestUserText == "Latest")
        #expect(state.latestAssistantText == "Hello back")
        #expect(state.activeRequestID == "r2")
    }

    @Test func disconnectIsExplicitAndDoesNotInventAReply() {
        var state = FatCatMiniChatState()
        state.appendUser("Hello", requestID: "r1")
        state.disconnected()

        #expect(state.connectionDetail == "FatCat Agent disconnected")
        #expect(state.latestAssistantText == nil)
        #expect(state.activeRequestID == nil)
    }
}
