import AppKit
import Combine
import CoreGraphics
import CoreMedia
import Foundation
import PeppaAnywhereCore
import ScreenCaptureKit
import SwiftUI
import WebKit

struct CaptureStatusPayload: Codable {
    let authorized: Bool
    let capturing: Bool
    let paused: Bool
    let status: String
}

@MainActor
final class CaptureCoordinator: NSObject, ObservableObject {
    @Published private(set) var status = "Permission has not been requested."
    @Published private(set) var isPaused = false
    @Published private(set) var isCapturing = false

    private var stream: SCStream?
    private let output = CaptureOutput()
    private var privateApps = Set<String>()
    private var captureState = CaptureState()
    var onObservation: ((ObservationPayload) -> Void)?
    var onStatus: ((CaptureStatusPayload) -> Void)?

    override init() {
        super.init()
        output.onFrame = { [weak self] in self?.emitStructuredObservation() }
    }

    func sendCurrentStatus() {
        onStatus?(CaptureStatusPayload(authorized: captureState.isAuthorized, capturing: isCapturing, paused: isPaused, status: status))
    }

    private func updateStatus(_ next: String) {
        status = next
        sendCurrentStatus()
    }

    func requestScreenAccess() {
        if !CGPreflightScreenCaptureAccess() {
            updateStatus("macOS permission dialog requested. Approve Screen Recording in System Settings.")
            _ = CGRequestScreenCaptureAccess()
        }

        guard CGPreflightScreenCaptureAccess() else {
            updateStatus("Waiting for Screen Recording permission.")
            return
        }

        captureState.authorize()
        Task { await startCaptureIfPermitted() }
    }

    func setPrivateApps(_ apps: [String]) {
        privateApps = Set(apps.map { $0.lowercased() })
    }

    func setPaused(_ paused: Bool) {
        if paused {
            captureState.pause()
            isPaused = true
            updateStatus("Pausing ScreenCaptureKit…")
            Task { await stopCapture() }
        } else {
            captureState.resume()
            isPaused = false
            guard captureState.isAuthorized else {
                updateStatus("Permission is required before observation can resume.")
                return
            }
            updateStatus("Resuming ScreenCaptureKit…")
            Task { await startCaptureIfPermitted() }
        }
    }

    private func startCaptureIfPermitted() async {
        guard captureState.isAuthorized, !captureState.isPaused, stream == nil else { return }
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first else {
                updateStatus("Screen Recording is allowed, but no display is available.")
                return
            }

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let configuration = SCStreamConfiguration()
            configuration.width = 2
            configuration.height = 2
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 2)
            configuration.queueDepth = 1
            configuration.showsCursor = false

            let nextStream = SCStream(filter: filter, configuration: configuration, delegate: nil)
            try nextStream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
            try await nextStream.startCapture()
            stream = nextStream
            captureState.started()
            isCapturing = captureState.isCapturing
            updateStatus("ScreenCaptureKit connected; pixel buffers are discarded.")
            emitStructuredObservation()
        } catch {
            updateStatus("ScreenCaptureKit could not start: \(error.localizedDescription)")
        }
    }

    private func stopCapture() async {
        if let activeStream = stream {
            try? await activeStream.stopCapture()
        }
        stream = nil
        captureState.stopped()
        isCapturing = false
        if isPaused { updateStatus("Observation paused; ScreenCaptureKit stopped.") }
    }

    private func emitStructuredObservation() {
        guard isCapturing, !isPaused else { return }
        let app = ActiveApplication(
            pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1,
            name: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown app"
        )
        let payload = ObservationFactory.make(
            application: app,
            window: frontmostWindow(),
            policy: PrivacyPolicy(privateApps: privateApps),
            timestamp: ISO8601DateFormatter().string(from: Date())
        )
        onObservation?(payload)
    }

    private func frontmostWindow() -> WindowCandidate? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        let candidates = windows?.enumerated().map { index, window in
            WindowCandidate(
                ownerPID: (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? -1,
                ownerName: window[kCGWindowOwnerName as String] as? String ?? "",
                layer: (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0,
                onScreen: (window[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false,
                title: window[kCGWindowName as String] as? String ?? "",
                order: index
            )
        } ?? []
        return WindowSelector.frontmostWindow(candidates, application: ActiveApplication(pid: NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1, name: NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown app"))
    }
}

private final class CaptureOutput: NSObject, SCStreamOutput {
    var onFrame: (() -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        // Deliberately do not read, encode, write, or upload the pixel buffer.
        onFrame?()
    }
}

@MainActor
final class WebCompanionController: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    let capture: CaptureCoordinator
    weak var webView: WKWebView?

    init(capture: CaptureCoordinator) {
        self.capture = capture
        super.init()
        capture.onObservation = { [weak self] observation in self?.send(observation) }
        capture.onStatus = { [weak self] status in self?.send(status) }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "request-screen-access": capture.requestScreenAccess()
        case "pause-observation": capture.setPaused(true)
        case "resume-observation": capture.setPaused(false)
        case "set-private-apps":
            if let apps = body["apps"] as? [String] { capture.setPrivateApps(apps) }
        default: break
        }
    }

    private func send(_ observation: ObservationPayload) {
        guard let data = try? JSONEncoder().encode(observation), let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.dispatchEvent(new CustomEvent('peppa:observation', { detail: \(json) }));")
    }

    private func send(_ status: CaptureStatusPayload) {
        guard let data = try? JSONEncoder().encode(status), let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.dispatchEvent(new CustomEvent('peppa:capture-status', { detail: \(json) }));")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        sendCurrentStatus()
    }

    private func sendCurrentStatus() {
        capture.sendCurrentStatus()
    }
}

struct WebSurface {
    let url: URL
    let localReadAccess: URL?
    let description: String

    static func resolve() -> WebSurface {
        if let override = ProcessInfo.processInfo.environment["PEPPA_DEV_SERVER_URL"], let url = URL(string: override) {
            return WebSurface(url: url, localReadAccess: nil, description: "development server \(url.absoluteString)")
        }
        let webRoot = Bundle.module.bundleURL
        if let index = Bundle.module.url(forResource: "index", withExtension: "html") {
            return WebSurface(url: index, localReadAccess: webRoot, description: "bundled production assets")
        }
        let fallback = """
        <html><body style="font: -apple-system-body; padding: 32px"><h2>Peppa Anywhere assets are missing</h2><p>Run scripts/prepare-peppa-web-assets.sh, or set PEPPA_DEV_SERVER_URL to a running local Vite server.</p></body></html>
        """
        let encoded = fallback.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return WebSurface(url: URL(string: "data:text/html,\(encoded)")!, localReadAccess: nil, description: "asset fallback")
    }
}

struct CompanionWebView: NSViewRepresentable {
    let controller: WebCompanionController
    let surface: WebSurface

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let nativeScript = """
        window.__PEPPA_NATIVE__ = {
          requestScreenAccess: function() { window.webkit.messageHandlers.peppa.postMessage({type: 'request-screen-access'}); },
          setObservationPaused: function(paused) { window.webkit.messageHandlers.peppa.postMessage({type: paused ? 'pause-observation' : 'resume-observation'}); },
          setPrivateApps: function(apps) { window.webkit.messageHandlers.peppa.postMessage({type: 'set-private-apps', apps: apps}); },
          isAvailable: function() { return true; }
        };
        """
        configuration.userContentController.addUserScript(WKUserScript(source: nativeScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        configuration.userContentController.add(controller, name: "peppa")
        let webView = WKWebView(frame: .zero, configuration: configuration)
        controller.webView = webView
        webView.navigationDelegate = controller
        if let localReadAccess = surface.localReadAccess {
            webView.loadFileURL(surface.url, allowingReadAccessTo: localReadAccess)
        } else {
            webView.load(URLRequest(url: surface.url))
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct FloatingWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.titleVisibility = .visible
        }
    }
}

struct PeppaAnywhereWindow: View {
    @ObservedObject var capture: CaptureCoordinator
    @State private var controller: WebCompanionController
    private let surface: WebSurface

    init(capture: CaptureCoordinator) {
        self.capture = capture
        _controller = State(initialValue: WebCompanionController(capture: capture))
        surface = WebSurface.resolve()
        print("Peppa Anywhere web surface: \(surface.description)")
    }

    var body: some View {
        CompanionWebView(controller: controller, surface: surface)
            .background(FloatingWindowConfigurator())
            .overlay(alignment: .bottomLeading) {
                Text(capture.status)
                    .font(.caption)
                    .padding(8)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(12)
            }
            .frame(minWidth: 760, minHeight: 640)
    }
}

@main
struct PeppaAnywhereApp: App {
    @StateObject private var capture = CaptureCoordinator()

    var body: some Scene {
        WindowGroup("Peppa Anywhere") {
            PeppaAnywhereWindow(capture: capture)
        }
        .defaultSize(width: 900, height: 720)
        .windowResizability(.contentSize)
    }
}
