import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import CoreMedia
import Foundation
import PeppaAnywhereCore
import ScreenCaptureKit
import SwiftUI
import Vision
import WebKit

@MainActor
final class ScreenPerceptionCoordinator: NSObject, ObservableObject {
    @Published private(set) var status = "Observation is off until Screen Recording is approved."
    @Published private(set) var isPaused = false
    @Published private(set) var isCapturing = false

    private var stream: SCStream?
    private let output = CaptureOutput()
    private var privateApps = Set<String>()
    private var latestOCRText: [String] = []
    var onObservation: ((ObservationPayload) -> Void)?

    override init() {
        super.init()
        output.onFrame = { [weak self] in self?.emitObservation() }
        output.onOCR = { [weak self] text in
            guard let self, !self.isPrivateForegroundApp else { return }
            self.latestOCRText = text
            self.emitObservation()
        }
        output.shouldDiscardOCR = { [weak self] in self?.isPrivateForegroundApp ?? true }
    }

    func requestAccess() {
        if !CGPreflightScreenCaptureAccess() {
            status = "Approve Screen Recording for FatCat in System Settings."
            _ = CGRequestScreenCaptureAccess()
        }
        guard CGPreflightScreenCaptureAccess() else {
            status = "Waiting for Screen Recording permission."
            return
        }
        Task { await start() }
    }

    func setPrivateApps(_ apps: [String]) { privateApps = Set(apps.map { $0.lowercased() }) }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        if paused {
            status = "Observation paused."
            Task { await stop() }
        } else {
            requestAccess()
        }
    }

    private func start() async {
        guard !isPaused, stream == nil else { return }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                status = "Screen Recording is allowed, but no display is available."
                return
            }
            let configuration = SCStreamConfiguration()
            configuration.width = 1280
            configuration.height = 720
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 2)
            configuration.queueDepth = 1
            configuration.showsCursor = false
            let next = SCStream(filter: SCContentFilter(display: display, excludingWindows: []), configuration: configuration, delegate: nil)
            try next.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
            try await next.startCapture()
            stream = next
            isCapturing = true
            status = "Observing privacy-filtered app, window, and accessibility context."
            emitObservation()
        } catch {
            status = "ScreenCaptureKit could not start: \(error.localizedDescription)"
        }
    }

    private func stop() async {
        if let stream { try? await stream.stopCapture() }
        stream = nil
        isCapturing = false
    }

    private func emitObservation() {
        guard isCapturing, !isPaused else { return }
        let workspaceApp = NSWorkspace.shared.frontmostApplication
        let application = ActiveApplication(pid: workspaceApp?.processIdentifier ?? -1, name: workspaceApp?.localizedName ?? "Unknown app")
        let title = accessibilityWindowTitle(for: application.pid) ?? frontmostWindowTitle(for: application)
        let redacted = privateApps.contains(application.name.lowercased())
        onObservation?(ObservationPayload(
            activeApp: redacted ? "Private application" : application.name,
            visibleWindow: redacted ? "Private window" : (title ?? "Untitled window"),
            task: "",
            detectedEvent: "screen_context_updated",
            repeatedActivity: "",
            likelyUserState: "active",
            confidence: title == nil ? 0.55 : 0.9,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            privacy: PrivacyPayload(redacted: redacted, reason: redacted ? "private application policy" : "structured metadata only")
            , visibleText: redacted ? [] : latestOCRText
        ))
    }

    private var isPrivateForegroundApp: Bool {
        guard let name = NSWorkspace.shared.frontmostApplication?.localizedName else { return false }
        return privateApps.contains(name.lowercased())
    }

    private func accessibilityWindowTitle(for pid: pid_t) -> String? {
        guard pid > 0 else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let window = focusedWindow else { return nil }
        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success else { return nil }
        return title as? String
    }

    private func frontmostWindowTitle(for application: ActiveApplication) -> String? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        let candidates = windows.enumerated().map { index, window in
            WindowCandidate(
                ownerPID: (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? -1,
                ownerName: window[kCGWindowOwnerName as String] as? String ?? "",
                layer: (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0,
                onScreen: (window[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false,
                title: window[kCGWindowName as String] as? String ?? "",
                order: index
            )
        }
        return WindowSelector.frontmostWindowName(candidates, application: application)
    }
}

private final class CaptureOutput: NSObject, SCStreamOutput {
    var onFrame: (() -> Void)?
    var onOCR: (([String]) -> Void)?
    var shouldDiscardOCR: (() -> Bool)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        if let pixelBuffer = sampleBuffer.imageBuffer, !(shouldDiscardOCR?() ?? true) {
            let request = VNRecognizeTextRequest { [weak self] request, _ in
                let text = (request.results as? [VNRecognizedTextObservation] ?? []).compactMap { $0.topCandidates(1).first?.string }.filter { !$0.isEmpty }
                self?.onOCR?(text)
            }
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
        }
        onFrame?()
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var text: String
    var requestID: String?
    var isStreaming: Bool
    var errorMessage: String?
    enum Role { case user, assistant, system }

    init(id: UUID = UUID(), role: Role, text: String, requestID: String? = nil, isStreaming: Bool = false, errorMessage: String? = nil) {
        self.id = id
        self.role = role
        self.text = text
        self.requestID = requestID
        self.isStreaming = isStreaming
        self.errorMessage = errorMessage
    }
}

@MainActor
final class PetModel: ObservableObject {
    @Published var life = FatCatLife()
    @Published var isChatOpen = false
    @Published var isExpanded = false
    @Published var draft = ""
    @Published var messages: [ChatMessage] = []
    @Published var agentStatus = "FatCat Agent is not connected."
    @Published var providerSetup = FatCatProviderSetupState()
    @Published var chatScrollState = ChatScrollState()
    @Published var isGenerating = false
    @Published var currentRequestID: String?
    @Published var resumeError: String?
    @Published var conversations: [FatCatConversationRecord] = []
    @Published var selectedConversationID: String?
    @Published var isShowingHistory = false
    @Published var focusComposerToken = 0
    var retryState = FatCatRetryState()

    func handleLife(_ event: FatCatLifeEvent, at now: Date = Date()) {
        var next = life
        next.handle(event, at: now)
        life = next
    }

    func appendUser(_ text: String) {
        messages.append(ChatMessage(role: .user, text: text))
        retryState.record(text)
        chatScrollState.noteContentChanged()
    }

    func beginAssistant(requestID: String) {
        currentRequestID = requestID
        isGenerating = true
        if let index = messages.lastIndex(where: { $0.role == .assistant && $0.requestID == requestID }) {
            messages[index].isStreaming = true
        } else {
            messages.append(ChatMessage(role: .assistant, text: "", requestID: requestID, isStreaming: true))
        }
        chatScrollState.noteContentChanged()
    }

    func appendAssistant(_ text: String, requestID: String) {
        if let index = messages.lastIndex(where: { $0.role == .assistant && $0.requestID == requestID }) {
            messages[index].text += text
            messages[index].isStreaming = true
        } else {
            beginAssistant(requestID: requestID)
            messages[messages.count - 1].text = text
        }
        chatScrollState.noteStreamingChanged()
    }

    func completeAssistant(requestID: String) {
        if let index = messages.lastIndex(where: { $0.requestID == requestID }) { messages[index].isStreaming = false }
        isGenerating = false
        currentRequestID = nil
        chatScrollState.noteContentChanged()
    }

    func failAssistant(requestID: String, message: String) {
        if let index = messages.lastIndex(where: { $0.requestID == requestID }) {
            messages[index].isStreaming = false
            messages[index].errorMessage = message
        }
        isGenerating = false
        currentRequestID = nil
        chatScrollState.noteContentChanged()
    }

    func appendSystem(_ text: String) {
        messages.append(ChatMessage(role: .system, text: text))
        chatScrollState.noteContentChanged()
    }

    func replaceMessages(_ messages: [ChatMessage]) {
        self.messages = messages
        retryState.clear()
        if let prompt = messages.last(where: { $0.role == .user })?.text { retryState.record(prompt) }
        chatScrollState.opened()
        chatScrollState.noteContentChanged()
    }
}

@MainActor
final class PeppaAgentClient: ObservableObject {
    @Published private(set) var status = "FatCat Agent is not connected."
    var onMessage: ((PeppaIPCMessage) -> Void)?

    private var process: Process?
    private var socketHandle: FileHandle?
    private var buffer = Data()
    private let socketPath: URL
    private let hermesHome: URL
    private var launchTask: Task<Void, Never>?

    init() {
        let baseSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let support = baseSupport.appendingPathComponent("FatCat", isDirectory: true)
        socketPath = support.appendingPathComponent("peppa-agent.sock")
        hermesHome = URL(fileURLWithPath: ProcessInfo.processInfo.environment["FATCAT_HERMES_PATH"] ?? support.appendingPathComponent("Hermes", isDirectory: true).path, isDirectory: true)
    }

    func newSession(conversationID: String, cwd: String) {
        request(.newSession(requestID: UUID().uuidString, conversationID: conversationID, cwd: cwd))
    }

    func loadSession(conversationID: String, sessionID: String, cwd: String) {
        request(.loadSession(requestID: UUID().uuidString, conversationID: conversationID, sessionID: sessionID, cwd: cwd))
    }

    func requestProviderInventory() {
        request(.providerInventory(requestID: UUID().uuidString))
    }

    func requestProviderModels(providerID: String, refresh: Bool = false) {
        request(.providerModels(requestID: UUID().uuidString, providerID: providerID, refresh: refresh))
    }

    func setProviderDefault(providerID: String, model: String) {
        request(.providerSetDefault(requestID: UUID().uuidString, providerID: providerID, model: model))
    }

    func setProviderBaseURL(providerID: String, baseURL: String) {
        request(.providerSetBaseURL(requestID: UUID().uuidString, providerID: providerID, baseURL: baseURL))
    }

    func validateProvider(providerID: String, model: String) {
        request(.providerValidate(requestID: UUID().uuidString, providerID: providerID, model: model))
    }

    func configureProviderCredential(providerID: String, credentialRef: String, baseURL: String?) {
        launchTask?.cancel()
        launchTask = Task { [weak self] in
            guard let self else { return }
            await ensureConnected()
            try? write(.providerSetCredentialRef(requestID: UUID().uuidString, providerID: providerID, credentialRef: credentialRef))
            if let baseURL {
                try? write(.providerSetBaseURL(requestID: UUID().uuidString, providerID: providerID, baseURL: baseURL))
            }
            try? await Task.sleep(for: .milliseconds(150))
            closeRuntime()
            await ensureConnected()
        }
    }

    func send(text: String, sessionID: String, observation: ObservationPayload?, requestID: String = UUID().uuidString) {
        launchTask?.cancel()
        launchTask = Task { [weak self] in
            guard let self else { return }
            await self.ensureConnected()
            try? self.write(.userMessage(requestID: requestID, sessionID: sessionID, text: Self.prompt(text, observation: observation)))
        }
    }

    func send(observation: ObservationPayload) {
        guard socketHandle != nil else { return }
        try? write(.observation(requestID: nil, activeApp: observation.activeApp, window: observation.visibleWindow, visibleText: [], confidence: observation.confidence))
    }

    func stopGeneration(sessionID: String) {
        request(.cancel(requestID: UUID().uuidString, sessionID: sessionID))
    }

    func reconnect() {
        stop()
        launchTask = Task { [weak self] in
            await self?.ensureConnected()
        }
    }

    func stop() {
        launchTask?.cancel()
        if socketHandle != nil { try? write(.shutdown) }
        closeRuntime()
        status = "FatCat Agent stopped."
    }

    private func closeRuntime() {
        socketHandle?.readabilityHandler = nil
        try? socketHandle?.close()
        socketHandle = nil
        process?.terminate()
        process = nil
        try? FileManager.default.removeItem(at: socketPath)
    }

    private func ensureConnected() async {
        if socketHandle != nil { return }
        guard let agent = agentExecutable() else {
            status = "FatCat Agent is not bundled. Run the packaging script before launching."
            return
        }
        do {
            try FileManager.default.createDirectory(at: hermesHome, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = agent
            process.arguments = ["--socket", socketPath.path, "--hermes-home", hermesHome.path]
            var environment = ProcessInfo.processInfo.environment
            let credentials = FatCatCredentials()
            for (providerID, variable) in [
                ("openai-api", "OPENAI_API_KEY"),
                ("anthropic", "ANTHROPIC_API_KEY")
            ] {
                if let secret = try? credentials.read(providerID: providerID),
                   !secret.isEmpty {
                    environment[variable] = secret
                }
            }
            process.environment = environment
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try process.run()
            self.process = process
            status = "Connecting…"
            for _ in 0..<50 {
                if Task.isCancelled { return }
                if connectSocket() {
                    try? write(.hello)
                    status = "Connected"
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
            status = "FatCat Agent did not become ready."
        } catch {
            status = "FatCat Agent could not start: \(error.localizedDescription)"
        }
    }

    private func connectSocket() -> Bool {
        #if os(macOS)
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return false }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.path.utf8) + [UInt8(0)]
        guard pathBytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { close(descriptor); return false }
        withUnsafeMutableBytes(of: &address.sun_path) { bytes in bytes.copyBytes(from: pathBytes) }
        let result = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard result == 0 else { close(descriptor); return false }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        handle.readabilityHandler = { [weak self] file in
            let data = file.availableData
            guard !data.isEmpty else {
                Task { @MainActor [weak self] in self?.handleDisconnect() }
                return
            }
            Task { @MainActor [weak self] in self?.consume(data) }
        }
        socketHandle = handle
        return true
        #else
        return false
        #endif
    }

    private func write(_ message: PeppaIPCMessage) throws {
        guard let socketHandle else { throw PeppaIPCError.malformed("agent socket is not connected") }
        try socketHandle.write(contentsOf: PeppaIPCCodec.encode(message: message))
    }

    private func consume(_ data: Data) {
        buffer.append(data)
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.prefix(upTo: newline)
            buffer.removeSubrange(...newline)
            guard let message = try? PeppaIPCCodec.decodeLine(Data(line)) else {
                status = "FatCat Agent sent an invalid protocol event."
                continue
            }
            onMessage?(message)
        }
    }

    private func handleDisconnect() {
        socketHandle?.readabilityHandler = nil
        try? socketHandle?.close()
        socketHandle = nil
        process?.terminate()
        process = nil
        status = "Disconnected — reconnect to continue."
    }

    private func agentExecutable() -> URL? {
        if let override = ProcessInfo.processInfo.environment["FATCAT_AGENT_PATH"], !override.isEmpty { return URL(fileURLWithPath: override) }
        let candidates = [
            Bundle.main.url(forResource: "PeppaAgent/PeppaAgent", withExtension: nil),
            Bundle.module.url(forResource: "PeppaAgent/PeppaAgent", withExtension: nil)
        ]
        return candidates.compactMap { $0 }.first(where: { url in
            var isDirectory = ObjCBool(false)
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
            return FileManager.default.isExecutableFile(atPath: url.path)
        })
    }

    private static func prompt(_ text: String, observation: ObservationPayload?) -> String {
        guard let observation else { return text }
        return """
        Privacy-filtered screen context:
        active app: \(observation.activeApp)
        window: \(observation.visibleWindow)
        event: \(observation.detectedEvent)
        user message: \(text)
        """
    }

    private func request(_ message: PeppaIPCMessage) {
        launchTask?.cancel()
        launchTask = Task { [weak self] in
            guard let self else { return }
            await self.ensureConnected()
            try? self.write(message)
        }
    }
}

private final class FatCatAvatarWebView: WKWebView {
    private var dragMouse = NSPoint.zero
    private var dragOrigin = NSPoint.zero

    override var acceptsFirstResponder: Bool { false }

    override func mouseDown(with event: NSEvent) {
        dragMouse = NSEvent.mouseLocation
        dragOrigin = window?.frame.origin ?? .zero
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        guard hypot(mouse.x - dragMouse.x, mouse.y - dragMouse.y) >= 4 else { return }
        let next = PetPosition.dragging(
            origin: PetPosition(x: dragOrigin.x, y: dragOrigin.y),
            startMouse: PetPosition(x: dragMouse.x, y: dragMouse.y),
            mouse: PetPosition(x: mouse.x, y: mouse.y)
        )
        window.setFrameOrigin(NSPoint(x: next.x, y: next.y))
    }
}

struct FatCatAvatarView: NSViewRepresentable {
    let animationKey: String
    let onClick: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onClick: onClick) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
        configuration.userContentController.add(context.coordinator, name: "fatcatAvatar")

        let webView = FatCatAvatarWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        webView.underPageBackgroundColor = .clear
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        if #available(macOS 13.3, *) { webView.isInspectable = false }

        guard let avatarURL = Bundle.module.url(forResource: "avatar", withExtension: "html", subdirectory: "FatCatAvatar") else {
            assertionFailure("FatCat avatar surface is missing from the app bundle")
            return webView
        }
        webView.loadFileURL(avatarURL, allowingReadAccessTo: avatarURL.deletingLastPathComponent())
        context.coordinator.webView = webView
        context.coordinator.animationKey = animationKey
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.webView = webView
        context.coordinator.animationKey = animationKey
        context.coordinator.onClick = onClick
        context.coordinator.pushAnimationIfReady()
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        nsView.configuration.userContentController.removeScriptMessageHandler(forName: "fatcatAvatar")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var animationKey = "idle"
        var onClick: () -> Void
        private var isSurfaceReady = false

        init(onClick: @escaping () -> Void) { self.onClick = onClick }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            decisionHandler(FatCatAvatarNavigation.allows(navigationAction.request.url) ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isSurfaceReady = true
            pushAnimationIfReady()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "fatcatAvatar", let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
            if type == "ready" {
                isSurfaceReady = true
                pushAnimationIfReady()
            } else if type == "click" {
                onClick()
            }
        }

        func pushAnimationIfReady() {
            guard isSurfaceReady, let webView, let script = FatCatAvatarBridge.setAnimationJavaScript(animationKey) else { return }
            webView.evaluateJavaScript(script, completionHandler: nil)
        }
    }
}

private struct ChatBottomPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct FatCatComposer: NSViewRepresentable {
    @Binding var text: String
    let focusToken: Int
    let onSend: () -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        let editor = FatCatComposerTextView()
        editor.delegate = context.coordinator
        editor.onSend = onSend
        editor.onDismiss = onDismiss
        editor.string = text
        editor.font = .systemFont(ofSize: 14)
        editor.textColor = .labelColor
        editor.backgroundColor = .clear
        editor.drawsBackground = false
        editor.isRichText = false
        editor.isAutomaticSpellingCorrectionEnabled = true
        editor.isContinuousSpellCheckingEnabled = true
        editor.textContainerInset = NSSize(width: 7, height: 7)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        scroll.documentView = editor
        return scroll
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let editor = nsView.documentView as? FatCatComposerTextView else { return }
        context.coordinator.parent = self
        editor.onSend = onSend
        editor.onDismiss = onDismiss
        if editor.string != text { editor.string = text }
        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            nsView.window?.makeFirstResponder(editor)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: FatCatComposer
        var lastFocusToken = 0
        init(_ parent: FatCatComposer) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = editor.string
        }
    }
}

private final class FatCatComposerTextView: NSTextView {
    var onSend: (() -> Void)?
    var onDismiss: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let modifiers: ComposerModifier = [
            event.modifierFlags.contains(.shift) ? .shift : [],
            event.modifierFlags.contains(.command) ? .command : []
        ]
        let key: ComposerKey
        if event.keyCode == 36 || event.keyCode == 76 { key = .return }
        else if event.keyCode == 53 { key = .escape }
        else { key = .other }
        switch ComposerKeyBehavior.action(key: key, modifiers: modifiers, hasText: !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
        case .send:
            onSend?()
        case .dismiss:
            window?.makeFirstResponder(nil)
            onDismiss?()
        case .insertNewline, .none:
            super.keyDown(with: event)
        }
    }

    override func doCommand(by selector: Selector) {
        guard selector == #selector(insertNewline(_:)) else {
            super.doCommand(by: selector)
            return
        }
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        let modifiers: ComposerModifier = {
            var value: ComposerModifier = []
            if flags.contains(.shift) { value.insert(.shift) }
            if flags.contains(.command) { value.insert(.command) }
            return value
        }()
        let hasText = !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        switch ComposerKeyBehavior.action(key: .return, modifiers: modifiers, hasText: hasText) {
        case .send: onSend?()
        case .insertNewline: super.doCommand(by: selector)
        case .dismiss, .none: break
        }
    }
}

private struct FatCatMarkdownView: View {
    let markdown: String
    let onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(FatCatMarkdownParser.parse(markdown).enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .textSelection(.enabled)
        .environment(\.openURL, OpenURLAction { url in
            guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
                  NSWorkspace.shared.open(url) else { return .discarded }
            return .handled
        })
    }

    @ViewBuilder
    private func blockView(_ block: FatCatMarkdownBlock) -> some View {
        switch block {
        case let .paragraph(text): inlineText(text)
        case let .heading(level, text):
            inlineText(text).font(level <= 2 ? .system(size: 16, weight: .semibold) : .system(size: 14, weight: .semibold))
        case let .blockquote(text):
            HStack(spacing: 8) {
                Rectangle().fill(.secondary.opacity(0.35)).frame(width: 2)
                inlineText(text).foregroundStyle(.secondary)
            }
        case let .unorderedList(items):
            VStack(alignment: .leading, spacing: 5) { ForEach(Array(items.enumerated()), id: \.offset) { _, item in inlineText("•  \(item)") } }
        case let .orderedList(items):
            VStack(alignment: .leading, spacing: 5) { ForEach(Array(items.enumerated()), id: \.offset) { index, item in inlineText("\(index + 1).  \(item)") } }
        case let .code(language, text):
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(language ?? "code").font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Button { onCopy(text) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("Copy code")
                }.padding(.horizontal, 10).padding(.vertical, 7)
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(text).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).padding(10)
                }
            }
            .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        case let .table(headers, rows):
            VStack(alignment: .leading, spacing: 4) {
                HStack { ForEach(Array(headers.enumerated()), id: \.offset) { _, header in Text(header).fontWeight(.semibold).frame(minWidth: 90, alignment: .leading) } }
                Divider()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in HStack { ForEach(Array(row.enumerated()), id: \.offset) { _, cell in Text(cell).frame(minWidth: 90, alignment: .leading) } } }
            }.font(.system(size: 13))
        }
    }

    private func inlineText(_ text: String) -> Text {
        if let value = try? AttributedString(markdown: text) { return Text(value) }
        return Text(text)
    }
}

private struct FatCatMessageRow: View {
    let message: ChatMessage
    let onCopy: (String) -> Void
    let onEdit: () -> Void
    let onRetry: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            if message.role == .user { Spacer(minLength: 34) }
            if message.role == .assistant { Text("F").font(.system(size: 11, weight: .bold)).frame(width: 20, height: 20).background(.primary.opacity(0.1)).clipShape(Circle()) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 5) {
                if message.role == .assistant {
                    FatCatMarkdownView(markdown: message.text.isEmpty ? "Thinking…" : message.text, onCopy: onCopy)
                } else if message.role == .system {
                    HStack(spacing: 7) { Image(systemName: "info.circle"); Text(message.text) }
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                } else {
                    Text(message.text).font(.system(size: 14)).lineSpacing(3).textSelection(.enabled)
                }
                if let error = message.errorMessage {
                    HStack(spacing: 6) { Image(systemName: "exclamationmark.triangle"); Text(error); Button("Retry", action: onRetry).buttonStyle(.link) }
                        .font(.system(size: 12)).foregroundStyle(.red)
                }
                if isHovered {
                    HStack(spacing: 10) {
                        Button { onCopy(message.text) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("Copy")
                        if message.role == .user { Button { onEdit() } label: { Image(systemName: "pencil") }.buttonStyle(.plain).help("Edit and resend") }
                        if message.role == .assistant { Button { onRetry() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).help("Retry") }
                    }.font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, message.role == .user ? 12 : 0)
            .padding(.vertical, message.role == .user ? 8 : 1)
            .background(message.role == .user ? Color.primary.opacity(0.08) : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            if message.role != .user { Spacer(minLength: 24) }
        }
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message.role == .user ? "You" : (message.role == .assistant ? "FatCat" : "Notice"))
    }
}

struct ChatBubble: View {
    @ObservedObject var model: PetModel
    let onSend: () -> Void
    let onRetry: () -> Void
    let onReconnect: () -> Void
    let onStop: () -> Void
    let onClose: () -> Void
    let onExpand: () -> Void
    let onNewChat: () -> Void
    let onSelectConversation: (FatCatConversationRecord) -> Void
    let onDeleteConversation: (FatCatConversationRecord) -> Void
    let onRenameConversation: (FatCatConversationRecord, String) -> Void
    @State private var pendingScroll: DispatchWorkItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("FatCat").font(.system(size: 14, weight: .semibold))
                if model.isGenerating { Text("Thinking").font(.system(size: 11)).foregroundStyle(.secondary) }
                Spacer()
                Menu {
                    Button("New Chat", action: onNewChat)
                    Button("History") { model.isShowingHistory.toggle() }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).help("Chat menu")
                Button(action: onExpand) { Image(systemName: model.isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") }.buttonStyle(.plain).help("Expand chat")
                Button(action: onClose) { Image(systemName: "xmark") }.buttonStyle(.plain).help("Close chat")
            }

            if model.isShowingHistory {
                ConversationHistoryView(model: model, onSelect: onSelectConversation, onNewChat: onNewChat, onDelete: onDeleteConversation, onRename: onRenameConversation)
            } else if model.isExpanded && !model.conversations.isEmpty {
                HStack(alignment: .top, spacing: 14) {
                    ConversationHistoryView(model: model, onSelect: onSelectConversation, onNewChat: onNewChat, onDelete: onDeleteConversation, onRename: onRenameConversation)
                        .frame(width: 220)
                    transcript
                }
            } else {
                transcript
            }
        }
        .padding(16)
        .frame(width: model.isExpanded ? 780 : 425, height: model.isExpanded ? 690 : 520)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.13), radius: 18, y: 8)
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { viewport in
                ScrollViewReader { proxy in
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 13) {
                                if model.messages.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("What are you working on?").font(.system(size: 18, weight: .medium))
                                        Text("Ask FatCat to explain what’s on screen or help continue a task.").font(.system(size: 13)).foregroundStyle(.secondary)
                                        HStack {
                                            suggestion("Explain what’s on screen")
                                            suggestion("Help me continue this task")
                                        }
                                    }.padding(.vertical, 22)
                                } else {
                                    ForEach(model.messages) { message in
                                        FatCatMessageRow(message: message, onCopy: copy, onEdit: { edit(message.text) }, onRetry: onRetry)
                                    }
                                }
                                Color.clear.frame(height: 1).id("chat-bottom-anchor")
                                    .background(GeometryReader { geometry in Color.clear.preference(key: ChatBottomPreferenceKey.self, value: geometry.frame(in: .named("chat-scroll")).maxY) })
                            }
                            .padding(.horizontal, 3)
                            .padding(.vertical, 4)
                        }
                        .coordinateSpace(name: "chat-scroll")
                        .onPreferenceChange(ChatBottomPreferenceKey.self) { bottom in
                            let distance = max(0, bottom - viewport.size.height)
                            model.chatScrollState.updateViewport(isNearBottom: distance < 38)
                        }
                        .onAppear {
                            model.chatScrollState.opened()
                            DispatchQueue.main.async { proxy.scrollTo("chat-bottom-anchor", anchor: .bottom) }
                        }
                        .onChange(of: model.chatScrollState.latestMessageRevision) { _ in scheduleScroll(proxy) }

                        if model.chatScrollState.hasUnreadBelow {
                            Button {
                                model.chatScrollState.jumpToLatest()
                                withAnimation(.easeOut(duration: 0.22)) { proxy.scrollTo("chat-bottom-anchor", anchor: .bottom) }
                            } label: { Label("Jump to latest", systemImage: "arrow.down") }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .padding(10)
                        }
                    }
                }
            }
            .frame(minHeight: 180)

            if model.agentStatus != "Connected" && !model.agentStatus.isEmpty {
                HStack(spacing: 6) {
                    Circle().fill(.secondary).frame(width: 5, height: 5)
                    Text(model.agentStatus).lineLimit(1)
                    if !model.agentStatus.contains("Connecting") { Button("Reconnect", action: onReconnect).buttonStyle(.link) }
                }
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                FatCatComposer(text: $model.draft, focusToken: model.focusComposerToken, onSend: onSend, onDismiss: onClose)
                    .frame(minHeight: 34, maxHeight: 112)
                    .padding(.horizontal, 4)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                Button(action: model.isGenerating ? onStop : onSend) {
                    Image(systemName: model.isGenerating ? "stop.fill" : "arrow.up")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.borderedProminent)
                .clipShape(Circle())
                .disabled(!model.isGenerating && model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel(model.isGenerating ? "Stop generation" : "Send message")
            }
        }
    }

    private func suggestion(_ title: String) -> some View {
        Button(title) { model.draft = title; onSend() }.buttonStyle(.link).font(.system(size: 12))
    }

    private func scheduleScroll(_ proxy: ScrollViewProxy) {
        guard model.chatScrollState.shouldAutoScroll else { return }
        pendingScroll?.cancel()
        let work = DispatchWorkItem {
            guard model.chatScrollState.shouldAutoScroll else { return }
            withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo("chat-bottom-anchor", anchor: .bottom) }
        }
        pendingScroll = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: work)
    }

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func edit(_ text: String) {
        model.draft = text
        model.focusComposerToken += 1
    }

}

private struct ConversationHistoryView: View {
    @ObservedObject var model: PetModel
    let onSelect: (FatCatConversationRecord) -> Void
    let onNewChat: () -> Void
    let onDelete: (FatCatConversationRecord) -> Void
    let onRename: (FatCatConversationRecord, String) -> Void
    @State private var query = ""
    @State private var pendingDelete: FatCatConversationRecord?
    @State private var pendingRename: FatCatConversationRecord?
    @State private var renameText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("History").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("New Chat", action: onNewChat).buttonStyle(.link)
            }
            TextField("Search conversations", text: $query).textFieldStyle(.roundedBorder)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filtered) { record in
                        Button { onSelect(record) } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.title).lineLimit(1)
                                if !record.lastPreview.isEmpty { Text(record.lastPreview).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1) }
                            }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Rename") { renameText = record.title; pendingRename = record }
                            Button("Delete", role: .destructive) { pendingDelete = record }
                        }
                    }
                }
            }
        }
        .alert("Delete conversation?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) { if let pendingDelete { onDelete(pendingDelete) }; pendingDelete = nil }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { Text("This removes the local conversation reference. Hermes history is not silently replaced.") }
        .sheet(item: $pendingRename) { record in
            VStack(alignment: .leading, spacing: 12) {
                Text("Rename conversation").font(.headline)
                TextField("Title", text: $renameText)
                HStack { Spacer(); Button("Cancel") { pendingRename = nil }; Button("Save") { onRename(record, renameText); pendingRename = nil }.keyboardShortcut(.return) }
            }.padding(20).frame(width: 320)
        }
    }

    private var filtered: [FatCatConversationRecord] {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty else { return model.conversations }
        return model.conversations.filter { $0.title.lowercased().contains(value) || $0.lastPreview.lowercased().contains(value) }
    }
}

struct PetRootView: View {
    @ObservedObject var model: PetModel
    let onClick: () -> Void
    let onSend: () -> Void
    let onRetry: () -> Void
    let onReconnect: () -> Void
    let onStop: () -> Void
    let onClose: () -> Void
    let onExpand: () -> Void
    let onNewChat: () -> Void
    let onSelectConversation: (FatCatConversationRecord) -> Void
    let onDeleteConversation: (FatCatConversationRecord) -> Void
    let onRenameConversation: (FatCatConversationRecord, String) -> Void

    var body: some View {
        Group {
            if model.isChatOpen {
                HStack(alignment: .bottom, spacing: 12) {
                    FatCatAvatarView(animationKey: model.life.animationKey, onClick: onClick).frame(width: 200, height: 200)
                    ChatBubble(model: model, onSend: onSend, onRetry: onRetry, onReconnect: onReconnect, onStop: onStop, onClose: onClose, onExpand: onExpand, onNewChat: onNewChat, onSelectConversation: onSelectConversation, onDeleteConversation: onDeleteConversation, onRenameConversation: onRenameConversation)
                }.padding(14)
            } else {
                FatCatAvatarView(animationKey: model.life.animationKey, onClick: onClick).frame(width: 220, height: 220)
            }
        }.background(Color.clear)
    }
}

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PetWindowController: NSObject, NSWindowDelegate {
    private let perception: ScreenPerceptionCoordinator
    private let model = PetModel()
    private let agent = PeppaAgentClient()
    private let positionStore = PetPositionStore()
    private var auditStore: PeppaAuditStore?
    private let conversationStore: FatCatConversationStore
    private var latestObservation: ObservationPayload?
    private struct PendingPrompt {
        let conversationID: String
        let text: String
        let observation: ObservationPayload?
    }
    private var pendingPrompts: [PendingPrompt] = []
    private var pendingSessionConversationID: String?
    private var ignoredRequestIDs = Set<String>()
    private var activeSessionID: String?
    private var lastObservedApp: String?
    private var lastObservedWindow: String?
    private var panel: PetPanel!
    private var statusItem: NSStatusItem!
    private var secondaryWindows: [NSWindow] = []
    private var cancellables = Set<AnyCancellable>()

    init(perception: ScreenPerceptionCoordinator) {
        self.perception = perception
        auditStore = nil
        conversationStore = Self.makeConversationStore()
        super.init()
        model.conversations = conversationStore.records
        model.selectedConversationID = conversationStore.selectedID
        perception.onObservation = { [weak self] observation in
            self?.latestObservation = observation
            self?.recordObservation(observation)
            self?.agent.send(observation: observation)
            guard let self else { return }
            let app = observation.activeApp
            let window = observation.visibleWindow
            guard app != lastObservedApp || window != lastObservedWindow else { return }
            lastObservedApp = app
            lastObservedWindow = window
            model.handleLife(.observationChanged(app: app, window: window, redacted: observation.privacy.redacted))
        }
        agent.onMessage = { [weak self] message in self?.handleAgentMessage(message) }
        agent.$status.receive(on: RunLoop.main).sink { [weak self] value in self?.model.agentStatus = value }.store(in: &cancellables)
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] now in self?.model.handleLife(.tick, at: now) }
            .store(in: &cancellables)
        buildPanel()
        buildStatusItem()
    }

    private func recordObservation(_ observation: ObservationPayload) {
        if auditStore == nil {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Peppa", isDirectory: true)
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            auditStore = try? PeppaAuditStore(path: support.appendingPathComponent("peppa.sqlite3").path)
        }
        try? auditStore?.recordObservation(activeApp: observation.activeApp, window: observation.visibleWindow, redacted: observation.privacy.redacted)
    }

    func show() {
        let screen = (NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? NSRect(x: 80, y: 80, width: 1200, height: 800))
        if let saved = positionStore.load() {
            let bounds = PanelBounds(width: screen.width - 220, height: screen.height - 220)
            let relative = PetPosition(x: saved.x - screen.minX, y: saved.y - screen.minY).clamped(to: bounds)
            panel.setFrameOrigin(NSPoint(x: relative.x + screen.minX, y: relative.y + screen.minY))
        } else {
            panel.setFrameOrigin(NSPoint(x: screen.midX - 110, y: screen.minY + 80))
        }
        panel.orderFrontRegardless()
    }

    func stop() {
        positionStore.save(PetPosition(x: panel.frame.minX, y: panel.frame.minY))
        agent.stop()
    }

    private func buildPanel() {
        panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 220), styleMask: [.borderless], backing: .buffered, defer: false)
        panel.delegate = self
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: PetRootView(model: model, onClick: { [weak self] in self?.openChat() }, onSend: { [weak self] in self?.sendChat() }, onRetry: { [weak self] in self?.retryLastPrompt() }, onReconnect: { [weak self] in self?.agent.reconnect() }, onStop: { [weak self] in self?.stopGeneration() }, onClose: { [weak self] in self?.closeChat() }, onExpand: { [weak self] in self?.toggleExpanded() }, onNewChat: { [weak self] in self?.newChat() }, onSelectConversation: { [weak self] record in self?.selectConversation(record) }, onDeleteConversation: { [weak self] record in self?.deleteConversation(record) }, onRenameConversation: { [weak self] record, title in self?.renameConversation(record, title: title) }))
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "FatCat"
        statusItem.menu = makeMenu()
    }

    private func openChat() {
        guard !model.isChatOpen else { return }
        model.isChatOpen = true
        model.handleLife(.userOpenedChat)
        panel.setContentSize(NSSize(width: 660, height: 555))
        panel.makeKeyAndOrderFront(nil)
        resumeSelectedConversation()
    }

    private func closeChat() {
        model.isChatOpen = false
        model.isExpanded = false
        model.handleLife(.userClosedChat)
        panel.setContentSize(NSSize(width: 220, height: 220))
        panel.orderFrontRegardless()
    }

    private func toggleExpanded() {
        model.isExpanded.toggle()
        panel.setContentSize(model.isExpanded ? NSSize(width: 1020, height: 735) : NSSize(width: 660, height: 555))
    }

    private func sendChat(promptOverride: String? = nil) {
        let text = (promptOverride ?? model.draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if promptOverride == nil { model.draft = "" }
        if model.selectedConversationID == nil {
            let workspace = explicitWorkspace()
            guard let record = try? conversationStore.create(title: "New chat", workspacePath: workspace) else { return }
            model.conversations = conversationStore.records
            model.selectedConversationID = record.id
        }
        guard let recordID = model.selectedConversationID, let record = conversationStore.records.first(where: { $0.id == recordID }) else { return }
        if record.hermesSessionID == nil, record.title != "New chat", !record.lastPreview.isEmpty {
            model.appendSystem("This older conversation has no saved Hermes session. Start a new chat to continue it.")
            return
        }
        model.appendUser(text)
        model.handleLife(.userSentMessage(requestID: model.currentRequestID ?? UUID().uuidString, conversationID: record.id))
        try? conversationStore.update(recordID: record.id, title: record.title == "New chat" ? String(text.prefix(42)) : nil, preview: String(text.prefix(120)))
        model.conversations = conversationStore.records
        guard let sessionID = record.hermesSessionID, !sessionID.isEmpty else {
            pendingPrompts.append(PendingPrompt(conversationID: record.id, text: text, observation: latestObservation))
            if pendingSessionConversationID != record.id {
                pendingSessionConversationID = record.id
                agent.newSession(conversationID: record.id, cwd: record.workspacePath)
            }
            return
        }
        activeSessionID = sessionID
        if model.isGenerating {
            pendingPrompts.append(PendingPrompt(conversationID: record.id, text: text, observation: latestObservation))
            return
        }
        startPrompt(text: text, observation: latestObservation, sessionID: sessionID, conversationID: record.id)
    }

    private func startPrompt(text: String, observation: ObservationPayload?, sessionID: String, conversationID: String) {
        guard model.selectedConversationID == conversationID, isActiveSession(sessionID) else { return }
        let requestID = UUID().uuidString
        model.currentRequestID = requestID
        model.isGenerating = true
        agent.send(text: text, sessionID: sessionID, observation: observation, requestID: requestID)
    }

    private func startNextPendingPrompt(for conversationID: String, sessionID: String) {
        guard model.selectedConversationID == conversationID, !model.isGenerating,
              let index = pendingPrompts.firstIndex(where: { $0.conversationID == conversationID }) else { return }
        let pending = pendingPrompts.remove(at: index)
        startPrompt(text: pending.text, observation: pending.observation, sessionID: sessionID, conversationID: conversationID)
    }

    private func retryLastPrompt() {
        guard let prompt = model.retryState.promptForRetry else { return }
        sendChat(promptOverride: prompt)
    }

    private func stopGeneration() {
        guard let recordID = model.selectedConversationID,
              let sessionID = conversationStore.records.first(where: { $0.id == recordID })?.hermesSessionID else { return }
        if let requestID = model.currentRequestID { ignoredRequestIDs.insert(requestID) }
        model.handleLife(.userStoppedGeneration)
        agent.stopGeneration(sessionID: sessionID)
        if let requestID = model.currentRequestID { model.completeAssistant(requestID: requestID) }
        else { model.isGenerating = false }
    }

    private func abandonActiveTurn() {
        if let requestID = model.currentRequestID { ignoredRequestIDs.insert(requestID) }
        if model.isGenerating, let sessionID = activeSessionID { agent.stopGeneration(sessionID: sessionID) }
        pendingPrompts.removeAll()
        pendingSessionConversationID = nil
        model.currentRequestID = nil
        model.isGenerating = false
    }

    private func newChat() {
        abandonActiveTurn()
        let workspace = explicitWorkspace()
        guard let record = try? conversationStore.create(title: "New chat", workspacePath: workspace) else { return }
        model.conversations = conversationStore.records
        model.selectedConversationID = record.id
        model.messages = []
        model.retryState.clear()
        activeSessionID = nil
        model.resumeError = nil
        model.isShowingHistory = false
        model.chatScrollState.opened()
        pendingSessionConversationID = record.id
        model.handleLife(.userStartedNewChat)
        agent.newSession(conversationID: record.id, cwd: workspace)
    }

    private func selectConversation(_ record: FatCatConversationRecord) {
        guard model.selectedConversationID != record.id else { model.isShowingHistory = false; return }
        abandonActiveTurn()
        try? conversationStore.select(recordID: record.id)
        model.selectedConversationID = record.id
        model.isShowingHistory = false
        model.messages = []
        model.retryState.clear()
        model.resumeError = nil
        model.chatScrollState.opened()
        activeSessionID = record.hermesSessionID
        if let sessionID = record.hermesSessionID {
            agent.loadSession(conversationID: record.id, sessionID: sessionID, cwd: record.workspacePath)
        } else if !record.lastPreview.isEmpty {
            model.appendSystem("This older conversation has no saved Hermes session. Start a new chat to continue it.")
        }
    }

    private func deleteConversation(_ record: FatCatConversationRecord) {
        if model.selectedConversationID == record.id { abandonActiveTurn(); activeSessionID = nil }
        try? conversationStore.delete(recordID: record.id)
        model.conversations = conversationStore.records
        model.selectedConversationID = conversationStore.selectedID
        model.messages = []
        if let selectedID = model.selectedConversationID,
           let selected = conversationStore.records.first(where: { $0.id == selectedID }),
           let sessionID = selected.hermesSessionID {
            activeSessionID = sessionID
            agent.loadSession(conversationID: selected.id, sessionID: sessionID, cwd: selected.workspacePath)
        }
    }

    private func renameConversation(_ record: FatCatConversationRecord, title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        try? conversationStore.update(recordID: record.id, title: title)
        model.conversations = conversationStore.records
    }

    private func resumeSelectedConversation() {
        guard let recordID = model.selectedConversationID,
              let record = conversationStore.records.first(where: { $0.id == recordID }) else { return }
        guard let sessionID = record.hermesSessionID, !sessionID.isEmpty else {
            if !record.lastPreview.isEmpty {
                model.appendSystem("This older conversation has no saved Hermes session. Start a new chat to continue it.")
            }
            return
        }
        model.messages = []
        model.retryState.clear()
        model.chatScrollState.opened()
        activeSessionID = sessionID
        agent.loadSession(conversationID: record.id, sessionID: sessionID, cwd: record.workspacePath)
    }

    private func explicitWorkspace() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [UserDefaults.standard.string(forKey: "fatcat.workspace")].compactMap { $0 } + [home.path]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? home.path
    }

    private static func makeConversationStore() -> FatCatConversationStore {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("FatCat", isDirectory: true)
        let url = support.appendingPathComponent("conversations.json")
        return (try? FatCatConversationStore(fileURL: url)) ?? (try! FatCatConversationStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("fatcat-conversations.json")))
    }

    private func handleAgentMessage(_ message: PeppaIPCMessage) {
        switch message {
        case let .assistantDelta(requestID, sessionID, text):
            guard isActiveSession(sessionID), !ignoredRequestIDs.contains(requestID) else { return }
            model.handleLife(.hermes(.streamDelta))
            if model.currentRequestID != requestID { model.beginAssistant(requestID: requestID) }
            model.appendAssistant(text, requestID: requestID)
        case .plan:
            model.handleLife(.hermes(.plan))
        case let .toolCall(_, name, _):
            model.handleLife(.hermes(.toolCall(name: name)))
        case let .providerStatus(providerID, authenticated, detail):
            model.appendSystem("\(providerID): \(authenticated ? "available" : "unavailable") — \(detail)")
        case let .providerInventoryResult(_, providers):
            model.providerSetup.applyInventory(providers)
            for provider in model.providerSetup.connections {
                agent.requestProviderModels(providerID: provider.providerID)
            }
        case let .providerModelsResult(_, providerID, models):
            model.providerSetup.applyModels(providerID: providerID, models: models)
        case let .providerConfigured(_, operation, provider, modelName, credentialRef):
            if operation == "default", let modelName {
                model.providerSetup.setDefault(providerID: provider, model: modelName)
            } else if operation == "credential_ref", let credentialRef {
                model.providerSetup.applyCredentialReference(providerID: provider, reference: credentialRef)
            }
        case let .providerValidationResult(_, provider, modelName, usable, detail):
            model.providerSetup.applyValidation(FatCatProviderValidation(providerID: provider, model: modelName, usable: usable, detail: detail))
        case let .proposedAction(_, action, risk, reason):
            model.handleLife(.hermes(.permissionRequested))
            model.appendSystem("Proposed \(action) (\(risk)): \(reason)")
        case let .permissionRequest(_, action, risk, reason):
            model.handleLife(.hermes(.permissionRequested))
            model.appendSystem("Permission requested for \(action) (\(risk)): \(reason)")
        case let .actionResult(_, success, detail):
            model.handleLife(.hermes(success ? .actionSucceeded : .actionFailed))
            model.appendSystem(detail)
        case let .verificationResult(_, success, detail):
            model.handleLife(.hermes(success ? .verifiedSuccess : .verifiedFailure))
            model.appendSystem(detail)
        case let .memoryUpdate(sessionID, detail):
            guard isActiveSession(sessionID) else { return }
            model.appendSystem("Memory updated: \(detail)")
        case let .state(state):
            handleAgentState(state)
        case let .sessionState(state, sessionID, requestID):
            guard isActiveSession(sessionID) else { return }
            if let requestID, let currentRequestID = model.currentRequestID,
               requestID != currentRequestID, [.completed, .failed, .stopping].contains(state) { return }
            handleAgentState(state, requestID: requestID)
        case let .error(requestID, message):
            if let requestID, ignoredRequestIDs.contains(requestID) { return }
            model.handleLife(.hermes(.turnFailed))
            if let requestID = model.currentRequestID,
               model.messages.contains(where: { $0.requestID == requestID }) {
                model.failAssistant(requestID: requestID, message: message)
            } else {
                model.appendSystem(message)
                model.isGenerating = false
                model.currentRequestID = nil
            }
        case let .sessionReady(_, conversationID, sessionID):
            guard conversationID == model.selectedConversationID else {
                if pendingSessionConversationID == conversationID {
                    pendingSessionConversationID = nil
                    pendingPrompts.removeAll { $0.conversationID == conversationID }
                }
                return
            }
            activeSessionID = sessionID
            try? conversationStore.attachHermesSession(sessionID, to: conversationID)
            model.conversations = conversationStore.records
            pendingSessionConversationID = nil
            startNextPendingPrompt(for: conversationID, sessionID: sessionID)
        case let .sessionLoaded(_, conversationID, sessionID):
            guard conversationID == model.selectedConversationID else { return }
            activeSessionID = sessionID
            model.resumeError = nil
            try? conversationStore.attachHermesSession(sessionID, to: conversationID)
            model.conversations = conversationStore.records
        case let .sessionLoadFailed(_, conversationID, _, message):
            guard conversationID == model.selectedConversationID else { return }
            activeSessionID = nil
            model.resumeError = message
            model.appendSystem(message)
        case let .sessionHistory(conversationID, _, role, text):
            guard conversationID == model.selectedConversationID else { return }
            if role == "user" { model.appendUser(text) }
            else if role == "assistant" { let requestID = UUID().uuidString; model.beginAssistant(requestID: requestID); model.appendAssistant(text, requestID: requestID); model.completeAssistant(requestID: requestID) }
        case .newSession, .loadSession, .listSessions, .sessionList, .cancel, .hello, .helloAck, .userMessage, .observation, .shutdown, .shutdownAck,
             .providerInventory, .providerModels, .providerSetDefault, .providerSetCredentialRef, .providerSetBaseURL, .providerValidate:
            break
        }
    }

    private func isActiveSession(_ sessionID: String) -> Bool {
        guard let recordID = model.selectedConversationID,
              let record = conversationStore.records.first(where: { $0.id == recordID }) else { return false }
        return activeSessionID == sessionID && record.hermesSessionID == sessionID
    }

    private func handleAgentState(_ state: PeppaAgentState, requestID: String? = nil) {
        switch state {
        case .connecting: model.agentStatus = "Connecting…"
        case .ready: model.agentStatus = "Connected"
        case .sending, .thinking, .streaming:
            model.handleLife(.hermes(.thought))
        case .stopping:
            model.handleLife(.hermes(.turnFailed))
        case .completed:
            if let requestID = requestID ?? model.currentRequestID { model.completeAssistant(requestID: requestID) }
            model.handleLife(.hermes(.turnCompleted))
            if let conversationID = model.selectedConversationID, let sessionID = activeSessionID {
                startNextPendingPrompt(for: conversationID, sessionID: sessionID)
            }
        case .failed:
            if let requestID = requestID ?? model.currentRequestID { model.failAssistant(requestID: requestID, message: "FatCat Agent stopped before completing the response.") }
            model.handleLife(.hermes(.turnFailed))
            if let conversationID = model.selectedConversationID, let sessionID = activeSessionID {
                startNextPendingPrompt(for: conversationID, sessionID: sessionID)
            }
        case .working:
            model.handleLife(.hermes(.toolCall(name: "")))
        case .verifying:
            model.handleLife(.hermes(.actionSucceeded))
        case .waitingForApproval:
            model.handleLife(.hermes(.permissionRequested))
        case .error:
            model.handleLife(.hermes(.turnFailed))
        case .disconnected:
            model.agentStatus = "Disconnected — reconnect to continue."
            model.handleLife(.hermes(.disconnected))
        case .idle, .listening:
            break
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "New Chat", action: #selector(newChatFromMenu), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Search Conversations", action: #selector(searchConversationsFromMenu), keyEquivalent: "k"))
        menu.addItem(NSMenuItem(title: "Focus Composer", action: #selector(focusComposerFromMenu), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "Copy Last Response", action: #selector(copyLastResponseFromMenu), keyEquivalent: "c"))
        menu.items[3].keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: perception.isPaused ? "Resume Observation" : "Pause Observation", action: #selector(toggleObservation), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: "Memory", action: #selector(showMemory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Action History", action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit FatCat", action: #selector(quit), keyEquivalent: "q"))
        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func newChatFromMenu() { openChat(); newChat() }

    @objc private func searchConversationsFromMenu() { openChat(); model.isShowingHistory = true }

    @objc private func focusComposerFromMenu() { openChat(); model.focusComposerToken += 1 }

    @objc private func copyLastResponseFromMenu() {
        guard let text = model.messages.last(where: { $0.role == .assistant })?.text else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    @objc private func toggleObservation() {
        perception.setPaused(!perception.isPaused)
        model.handleLife(perception.isPaused ? .observationPaused : .observationResumed)
        statusItem.menu = makeMenu()
    }

    @objc private func showSettings() {
        agent.requestProviderInventory()
        let view = SettingsView(
            model: model,
            status: perception.status,
            isPaused: perception.isPaused,
            requestAccess: { [weak self] in self?.perception.requestAccess() },
            togglePause: { [weak self] in self?.toggleObservation() },
            refreshProviders: { [weak self] in self?.agent.requestProviderInventory() },
            refreshModels: { [weak self] providerID in self?.agent.requestProviderModels(providerID: providerID) },
            saveCredential: { [weak self] providerID, secret, baseURL in
                self?.saveProviderCredential(providerID: providerID, secret: secret, baseURL: baseURL) ?? false
            },
            setDefault: { [weak self] providerID, modelName in
                self?.agent.setProviderDefault(providerID: providerID, model: modelName)
                self?.agent.validateProvider(providerID: providerID, model: modelName)
            }
        )
        showSecondary(title: "FatCat Settings", size: NSSize(width: 520, height: 650), view: view)
    }

    private func saveProviderCredential(providerID: String, secret: String, baseURL: String?) -> Bool {
        do {
            let credentials = FatCatCredentials()
            try credentials.save(providerID: providerID, secret: secret)
            let reference = credentials.reference(providerID: providerID)
            agent.configureProviderCredential(providerID: providerID, credentialRef: reference, baseURL: baseURL)
            model.providerSetup.applyCredentialReference(providerID: providerID, reference: reference)
            if let baseURL, !baseURL.isEmpty {
                model.providerSetup.applyBaseURL(providerID: providerID, baseURL: baseURL)
            }
            return true
        } catch {
            return false
        }
    }

    @objc private func showMemory() {
        showSecondary(title: "FatCat Memory", size: NSSize(width: 380, height: 220), view: SimpleInfoView(title: "Memory", text: "FatCat Agent owns conversations, skills, goals, and memory in the isolated Hermes home. The Swift app retains no raw screenshots."))
    }

    @objc private func showHistory() {
        let historyText: String = model.messages.map { message in
            switch message.role { case .user: return "You: \(message.text)"; case .assistant: return "FatCat: \(message.text)"; case .system: return "System: \(message.text)" }
        }.joined(separator: "\n\n")
        showSecondary(title: "FatCat Action History", size: NSSize(width: 450, height: 320), view: SimpleInfoView(title: "Action History", text: historyText.isEmpty ? "No actions yet." : historyText))
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func showSecondary<Content: View>(title: String, size: NSSize, view: Content) {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
        window.title = title
        window.contentView = NSHostingView(rootView: view)
        window.center()
        window.makeKeyAndOrderFront(nil)
        secondaryWindows.append(window)
    }

    func windowDidMove(_ notification: Notification) { positionStore.save(PetPosition(x: panel.frame.minX, y: panel.frame.minY)) }

}

struct SettingsView: View {
    @ObservedObject var model: PetModel
    let status: String
    let isPaused: Bool
    let requestAccess: () -> Void
    let togglePause: () -> Void
    let refreshProviders: () -> Void
    let refreshModels: (_ providerID: String) -> Void
    let saveCredential: (_ providerID: String, _ secret: String, _ baseURL: String?) -> Bool
    let setDefault: (_ providerID: String, _ model: String) -> Void

    @State private var selectedProviderID = "openai-codex"
    @State private var modelName = ""
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var setupMessage: String?

    private var selectedConnection: FatCatProviderConnection? {
        model.providerSetup.connection(providerID: selectedProviderID)
    }

    var body: some View {
        ScrollView {
          VStack(alignment: .leading, spacing: 14) {
            Text("FatCat").font(.title3.weight(.semibold))
            Text("Screen context stays local and is reduced to privacy-filtered structured metadata.").font(.callout).foregroundStyle(.secondary)
            Label(status, systemImage: isPaused ? "pause.circle" : "eye").font(.caption)
            Label(model.agentStatus, systemImage: "brain").font(.caption).lineLimit(2)

            HStack {
                Text("Hermes providers").font(.headline)
                Spacer()
                Button("Refresh") { model.providerSetup = FatCatProviderSetupState(); refreshProviders() }
            }
            Text("Hermes owns provider detection and model discovery. FatCat only stores API secrets in the macOS Keychain.")
                .font(.caption).foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(model.providerSetup.connections) { provider in
                    Button {
                        selectedProviderID = provider.providerID
                        syncSelectedFields()
                    } label: {
                        HStack {
                            Image(systemName: icon(for: provider.status))
                                .foregroundStyle(color(for: provider.status))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(provider.displayName).foregroundStyle(.primary)
                                Text(provider.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if provider.isDefault { Text("Default").font(.caption.weight(.medium)).foregroundStyle(.blue) }
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()
            Text("Default Hermes model").font(.headline)
            if model.providerSetup.connections.isEmpty {
                Text("Connecting to the bundled Hermes runtime…").font(.caption).foregroundStyle(.secondary)
            } else {
                Picker("Provider", selection: $selectedProviderID) {
                    ForEach(model.providerSetup.connections) { provider in
                        Text(provider.displayName).tag(provider.providerID)
                    }
                }
                .onChange(of: selectedProviderID) { _ in
                    syncSelectedFields()
                    refreshModels(selectedProviderID)
                }

                if let selectedConnection, !selectedConnection.models.isEmpty {
                    Picker("Model", selection: $modelName) {
                        ForEach(selectedConnection.models, id: \.self) { model in Text(model).tag(model) }
                    }
                }
                TextField("Model ID", text: $modelName)
                    .textFieldStyle(.roundedBorder)
                Button("Use this provider and model") {
                    let provider = selectedProviderID.trimmingCharacters(in: .whitespacesAndNewlines)
                    let selectedModel = modelName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !provider.isEmpty, !selectedModel.isEmpty else { return }
                    setDefault(provider, selectedModel)
                }
                .disabled(modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if selectedProviderID == "openai-api" || selectedProviderID == "anthropic" {
                Divider()
                Text(selectedProviderID == "openai-api" ? "OpenAI-compatible API" : "Claude / Anthropic API").font(.headline)
                SecureField("API key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                if selectedProviderID == "openai-api" {
                    TextField("Base URL (optional)", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                    Text("For OpenAI-compatible servers, use an HTTPS or local HTTP endpoint such as https://api.example.com/v1.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Button("Save API settings") {
                    let secret = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !secret.isEmpty else {
                        setupMessage = "Enter an API key first."
                        return
                    }
                    let endpoint = selectedProviderID == "openai-api" ? baseURL.trimmingCharacters(in: .whitespacesAndNewlines) : ""
                    if saveCredential(selectedProviderID, secret, endpoint.isEmpty ? nil : endpoint) {
                        apiKey = ""
                        setupMessage = "Saved to the macOS Keychain. Hermes will restart with the new provider settings."
                    } else {
                        setupMessage = "FatCat could not save that API key to the macOS Keychain."
                    }
                }
                if let setupMessage { Text(setupMessage).font(.caption).foregroundStyle(.secondary) }
                if selectedConnection?.credentialReference != nil {
                    Label("API key is stored in Keychain", systemImage: "lock.fill").font(.caption).foregroundStyle(.secondary)
                }
            } else if selectedProviderID == "openai-codex" {
                Label("Codex subscription detection is handled by Hermes using the official Codex auth state.", systemImage: "checkmark.shield").font(.caption).foregroundStyle(.secondary)
            }

            HStack { Button("Request Screen Recording", action: requestAccess); Button(isPaused ? "Resume Observation" : "Pause Observation", action: togglePause) }
          }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { syncSelectedFields() }
        .onChange(of: model.providerSetup) { _ in syncSelectedFields() }
    }

    private func syncSelectedFields() {
        guard let connection = model.providerSetup.connection(providerID: selectedProviderID) else {
            if let first = model.providerSetup.connections.first {
                selectedProviderID = first.providerID
            }
            return
        }
        if modelName.isEmpty || (!connection.models.isEmpty && !connection.models.contains(modelName)) {
            modelName = connection.defaultModel ?? connection.models.first ?? modelName
        }
        baseURL = connection.baseURL ?? ""
    }

    private func icon(for status: FatCatProviderStatus) -> String {
        switch status { case .connected: return "checkmark.circle.fill"; case .needsSetup: return "circle.dotted"; case .error: return "exclamationmark.circle.fill"; case .unavailable: return "circle" }
    }

    private func color(for status: FatCatProviderStatus) -> Color {
        switch status { case .connected: return .green; case .error: return .orange; case .needsSetup, .unavailable: return .secondary }
    }
}

struct SimpleInfoView: View {
    let title: String
    let text: String
    var body: some View { VStack(alignment: .leading, spacing: 12) { Text(title).font(.title3.weight(.semibold)); ScrollView { Text(text).frame(maxWidth: .infinity, alignment: .leading) } }.padding(22) }
}

struct SettingsLandingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FatCat").font(.title3.weight(.semibold))
            Text("Use the FatCat menu-bar item to open live settings, provider discovery, memory, and action history.")
                .foregroundStyle(.secondary)
            Divider()
            Label("Screen context is opt-in and privacy-filtered.", systemImage: "lock.shield")
            Label("Hermes runs locally as the bundled FatCat Agent.", systemImage: "brain")
        }
        .padding(22)
        .frame(width: 380, alignment: .leading)
    }
}

@MainActor
final class PeppaAnywhereAppDelegate: NSObject, NSApplicationDelegate {
    private var perception: ScreenPerceptionCoordinator!
    private var windowController: PetWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        perception = ScreenPerceptionCoordinator()
        windowController = PetWindowController(perception: perception)
        windowController.show()
        DispatchQueue.main.async { [weak self] in
            self?.windowController.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) { windowController.stop() }
}

@main
struct PeppaAnywhereApp: App {
    @NSApplicationDelegateAdaptor(PeppaAnywhereAppDelegate.self) private var delegate

    init() {
        if CommandLine.arguments.contains("--verify-native-bundle") {
            guard Bundle.module.url(forResource: "avatar", withExtension: "html", subdirectory: "FatCatAvatar") != nil else {
                fputs("Bundled FatCat avatar surface is missing.\n", stderr)
                exit(EXIT_FAILURE)
            }
                print("Bundled FatCat avatar surface is readable.")
            exit(EXIT_SUCCESS)
        }
    }

    var body: some Scene { Settings { SettingsLandingView() } }
}
