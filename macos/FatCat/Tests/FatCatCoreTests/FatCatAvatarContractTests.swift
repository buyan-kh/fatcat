import Foundation
import FatCatCore
import Testing

struct FatCatAvatarContractTests {
    @Test func webViewAllowsInternalAvatarLoadsAndBlocksTheOpenWeb() {
        #expect(FatCatAvatarNavigation.allows(URL(string: "about:blank")))
        #expect(FatCatAvatarNavigation.allows(URL(fileURLWithPath: "/tmp/avatar.html")))
        #expect(FatCatAvatarNavigation.allows(nil))
        #expect(!FatCatAvatarNavigation.allows(URL(string: "https://example.com")))
        #expect(!FatCatAvatarNavigation.allows(URL(string: "http://example.com")))
    }

    @Test func animationBridgeEncodesAStringWithoutUsingJSONObjectSerialization() {
        #expect(FatCatAvatarBridge.setAnimationJavaScript("idle") == #"window.fatCatAvatar?.setAnimation("idle");"#)
        #expect(FatCatAvatarBridge.setAnimationJavaScript("thinking") == #"window.fatCatAvatar?.setAnimation("thinking");"#)
        #expect(FatCatAvatarBridge.setAnimationJavaScript(#"bad"key"#) == #"window.fatCatAvatar?.setAnimation("bad\"key");"#)
    }

    @Test func reactionCueJavaScriptIsWellFormedAndEscaped() {
        #expect(FatCatAvatarBridge.setReactionJavaScript(intensity: 0.8, durationMs: 650) == "window.fatCatAvatar?.setReaction(0.8, 650.0);")
        #expect(FatCatAvatarBridge.setReactionJavaScript(intensity: .nan, durationMs: 650) == nil)
    }

    @Test func productionDefinitionKeepsTheOriginalRoundGeometryAndCatalog() throws {
        let definition = try loadJSON("public/fatcat.avatar.json")
        let body = try #require(definition["body"] as? [String: Any])
        let primary = try #require(body["primary"] as? [String: Any])
        let colors = try #require(definition["colors"] as? [String: Any])
        let expressionOrder = try #require(definition["expressionOrder"] as? [String])
        let animationOrder = try #require(definition["animationOrder"] as? [String])

        #expect(definition["name"] as? String == "FatCat")
        #expect(primary["type"] as? String == "sphere")
        #expect(primary["width"] as? Double == 240)
        #expect(primary["height"] as? Double == 240)
        #expect(primary["depth"] as? Double == 240.03671875)
        #expect(primary["roundness"] as? Double == 1)
        #expect(colors["body"] as? String == "#F28C38" || colors["body"] as? String == "#f28c38")
        #expect(colors["eyes"] as? String == "#111316")
        #expect(expressionOrder.count == 28)
        #expect(animationOrder.count == 23)
        #expect(animationOrder.contains("idle"))
        #expect(animationOrder.contains("thinking"))
        #expect(animationOrder.contains("celebrate"))
    }

    @Test func originalExpressionAndAnimationKeysRemainInOrder() throws {
        let definition = try loadJSON("public/fatcat.avatar.json")
        let expressions = try #require(definition["expressions"] as? [String: Any])
        let animations = try #require(definition["animations"] as? [String: Any])
        let expressionOrder = try #require(definition["expressionOrder"] as? [String])
        let animationOrder = try #require(definition["animationOrder"] as? [String])

        #expect(Set(expressionOrder) == Set(expressions.keys))
        #expect(Set(animationOrder) == Set(animations.keys))
        #expect(expressionOrder.first == "neutral")
        #expect(animationOrder.first == "sleeping")
    }

    @Test func productPathUsesTransparentWebAvatarAndNotTheNativeRenderer() throws {
        let appMain = try loadText("macos/FatCat/Sources/FatCat/AppMain.swift")
        let manifest = try loadText("macos/FatCat/Package.swift")

        #expect(appMain.contains("allowFileAccessFromFileURLs"))
        #expect(appMain.contains("allowUniversalAccessFromFileURLs"))
        #expect(appMain.contains("WKWebView"))
        #expect(appMain.contains("FatCatAvatar"))
        #expect(appMain.contains("FatCatAvatarBridge.setAnimationJavaScript"))
        #expect(!appMain.contains("JSONSerialization.data(withJSONObject: animationKey)"))
        #expect(appMain.contains("drawsBackground"))
        #expect(appMain.contains("underPageBackgroundColor = .clear"))
        #expect(appMain.contains("acceptsFirstResponder"))
        #expect(!appMain.contains("layer?.isOpaque = false"))
        #expect(!appMain.contains("isFileURL == true ? .allow : .cancel"))
        #expect(!appMain.contains("FatCatAvatarRenderer"))
        #expect(!appMain.contains("SceneKit"))
        #expect(!appMain.contains("RealityKit"))
        #expect(manifest.contains("exclude: [\"FatCatAvatar.swift\"]"))
        #expect(manifest.contains("Resources/FatCatAvatar"))
    }

    @Test func productPathUsesEventLedFlightAndReactionCues() throws {
        let appMain = try loadText("macos/FatCat/Sources/FatCat/AppMain.swift")

        #expect(appMain.contains("onLifeEvent"))
        #expect(appMain.contains("reactionCue"))
        #expect(appMain.contains("flushPendingFlightIfSafe"))
        #expect(!appMain.contains("reason = .idleReposition"))
    }

    @Test func nativeWindowConnectsWithoutOwningAgentOrResizingPet() throws {
        let appMain = try loadText("macos/FatCat/Sources/FatCat/AppMain.swift")

        #expect(appMain.contains("panel.orderFrontRegardless()\n        agent.requestProviderInventory()\n        flightController.start(panel: panel)"))
        #expect(appMain.contains("runtime/fatcat-agent.sock"))
        #expect(!appMain.contains("private var process: Process?"))
        #expect(!appMain.contains("let process = Process()"))
        #expect(!appMain.contains("process?.terminate()"))
        #expect(!appMain.contains("try? write(.shutdown)"))
        #expect(!appMain.contains("removeItem(at: socketPath)"))
        #expect(!appMain.contains("panel.setContentSize"))
        #expect(appMain.contains("native-conversations-cache.json"))
        #expect(!appMain.contains("support.appendingPathComponent(\"conversations.json\")"))
        #expect(appMain.contains("outboundQueue"))
        #expect(appMain.contains("startReconnect()"))
        #expect(!appMain.contains("launchTask?.cancel()"))
    }

    @Test func flightControllerStartsAfterThePanelIsShownAndHasAnExplicitTestPath() throws {
        let appMain = try loadText("macos/FatCat/Sources/FatCat/AppMain.swift")
        #expect(appMain.contains("panel.orderFrontRegardless()\n        agent.requestProviderInventory()\n        flightController.start(panel: panel)"))
        #expect(appMain.contains("self?.evaluateFlight(now: Date())"))
        #expect(appMain.contains("try await Task.sleep(for: .seconds(Self.evaluationInterval))"))
        #expect(appMain.contains("panel.setFrameOrigin(NSPoint(x: frame.position.x, y: frame.position.y))"))
        #expect(appMain.contains("Button(\"Test flight\", action: testFlight)"))
        #expect(appMain.contains("bypassIdleAndCooldown: explicit"))
    }

    @Test func restoredPanelPositionUsesTheSavedDisplayInsteadOfTheCurrentMouseDisplay() throws {
        let appMain = try loadText("macos/FatCat/Sources/FatCat/AppMain.swift")
        let showStart = try #require(appMain.range(of: "    func show() {"))
        let showEnd = try #require(appMain[showStart.upperBound...].range(of: "    private static func screenForRestoredPosition"))
        let show = String(appMain[showStart.lowerBound..<showEnd.lowerBound])
        #expect(show.contains("screenForRestoredPosition(saved)"))
        #expect(!show.contains("NSEvent.mouseLocation"))
        #expect(appMain.contains("screenID: panel.screen.flatMap(Self.displayID)"))
    }

    @Test func electronWorkspaceUsesOneLauncherForAvatarAndMenu() throws {
        let appMain = try loadText("macos/FatCat/Sources/FatCat/AppMain.swift")
        let launcher = try loadText("macos/FatCat/Sources/FatCatCore/FatCatElectronLauncher.swift")
        let runScript = try loadText("scripts/run-fatcat-macos.sh")
        let dmgScript = try loadText("scripts/package-fatcat-dmg.sh")

        #expect(appMain.contains("FATCAT_ELECTRON_APP_PATH"))
        #expect(launcher.contains("FatCat Electron.app"))
        #expect(appMain.contains("runningApplications"))
        #expect(appMain.contains("onDoubleClick: { [weak self] in self?.openOrFocusElectron() }"))
        #expect(appMain.contains("openElectronWorkspaceFromMenu"))
        #expect(appMain.contains("private let electronLauncher = FatCatElectronWorkspaceLauncher()"))
        #expect(!appMain.contains("/Users/"))
        #expect(!appMain.contains("pkill"))
        #expect(runScript.contains("package-fatcat-electron.sh"))
        #expect(dmgScript.contains("FatCat Electron.app"))
    }

    private func loadJSON(_ relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repositoryRoot.appendingPathComponent(relativePath))
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func loadText(_ relativePath: String) throws -> String {
        try String(contentsOf: repositoryRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
