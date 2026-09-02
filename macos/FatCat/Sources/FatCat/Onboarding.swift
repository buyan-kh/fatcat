import AppKit
import ApplicationServices
import CoreGraphics
import FatCatCore
import SwiftUI

@MainActor
final class FatCatPermissionCoordinator {
    enum Feature { case screenAwareness, nativeActions }

    func request(_ feature: Feature, enableScreenAwareness: (() -> Void)? = nil) {
        switch feature {
        case .screenAwareness:
            enableScreenAwareness?()
        case .nativeActions:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }
}

private struct LaunchOverlayView: View {
    let reducedMotion: Bool
    let targetOffset: CGSize
    @State private var arrived = false

    var body: some View {
        ZStack {
            Color.black.opacity(arrived ? 0.10 : 0)
            RadialGradient(colors: [.orange.opacity(arrived ? 0.08 : 0), .clear], center: .center, startRadius: 30, endRadius: 520)
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(Color.orange.opacity(0.55))
                    .frame(width: 3 + CGFloat(index % 3), height: 3 + CGFloat(index % 3))
                    .offset(x: arrived ? CGFloat((index % 4) - 2) * 24 : CGFloat((index % 4) - 2) * 105,
                            y: arrived ? CGFloat((index / 4) - 1) * 25 : CGFloat((index / 4) - 1) * 120)
                    .offset(arrived ? targetOffset : .zero)
                    .opacity(arrived ? 0.15 : 0.7)
            }
            RoundedRectangle(cornerRadius: arrived ? 42 : 180)
                .stroke(Color.orange.opacity(arrived ? 0.42 : 0), lineWidth: 3)
                .frame(width: arrived ? 150 : 460, height: arrived ? 150 : 460)
                .blur(radius: 14)
                .offset(arrived ? targetOffset : .zero)
            VStack(spacing: 8) {
                HStack(spacing: 13) {
                    Capsule().fill(.orange).frame(width: 13, height: arrived ? 8 : 1)
                    Capsule().fill(.orange).frame(width: 13, height: arrived ? 8 : 1)
                }
                Text("Hi. I’m FatCat.").font(.system(size: 27, weight: .semibold, design: .rounded))
                Text("I live on your Mac and help through Hermes.").font(.callout).foregroundStyle(.secondary)
            }
            .padding(24).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
            .opacity(arrived ? 1 : 0)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: reducedMotion ? 0.15 : 1.15)) { arrived = true }
        }
    }
}

private struct LaunchSkipView: View {
    let skip: () -> Void
    var body: some View {
        Button("Skip", action: skip)
            .keyboardShortcut(.escape, modifiers: [])
            .buttonStyle(.bordered)
            .padding(10)
    }
}

private final class OnboardingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private struct OnboardingCard: View {
    let step: OnboardingStep
    let back: () -> Void
    let next: () -> Void
    let skip: () -> Void
    let providerSetup: () -> Void
    let testConnection: () -> Void
    let usefulTask: () -> Void
    let connectionStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { Text(title).font(.title2.bold()); Spacer(); Text("\(step.rawValue + 1) of \(OnboardingStep.allCases.count)").font(.caption).foregroundStyle(.secondary) }
            Text(bodyText).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if step == .provider { Button("Open Hermes provider setup", action: providerSetup) }
            if step == .privacy {
                Label("Permissions are requested only when you use a feature.", systemImage: "hand.raised.fill").font(.caption)
            }
            if step == .connection, let connectionStatus {
                Label(connectionStatus, systemImage: connectionStatus.hasPrefix("Connected") ? "checkmark.circle.fill" : "ellipsis.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Skip", action: skip).buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                if step != .meetFatCat { Button("Back", action: back) }
                Button(primaryTitle) {
                    if step == .connection { testConnection() } else {
                        if step == .usefulTask { usefulTask() }
                        next()
                    }
                }.buttonStyle(.borderedProminent).disabled(step == .connection && connectionStatus == "Waiting for Hermes…")
            }
        }
        .padding(22).frame(width: 410).background(.regularMaterial)
    }

    private var title: String {
        ["Meet FatCat", "Choose your agent provider", "Your privacy", "How to interact", "Meet Hermes", "Start with something useful"][step.rawValue]
    }
    private var bodyText: String {
        switch step {
        case .meetFatCat: return "I’m a small, local presence for Hermes.\n\nI can help you understand what’s on your screen, work through tasks, browse, write, and remember what matters to you."
        case .provider: return "Hermes already handles OpenAI Codex, OpenAI-compatible APIs, and Anthropic. Choose and configure the provider there—FatCat does not create a second provider system."
        case .privacy: return "FatCat can observe structured screen context when you allow it. Raw screenshots are not retained by default. You can pause observation at any time, and private apps can be excluded.\n\nIf you use an external model, relevant context is sent through Hermes to that provider."
        case .interaction: return "Click FatCat to open mini chat.\nDouble-click to open the full workspace.\nRight-click for actions and settings.\nDrag FatCat anywhere."
        case .connection: return "Let’s say hello to Hermes. FatCat will send a tiny real request and react to Hermes’ event stream."
        case .usefulTask: return "Try: “Help me understand what I’m looking at.”"
        }
    }
    private var primaryTitle: String {
        switch step { case .connection: return "Say hello"; case .usefulTask: return "Try it"; default: return "Continue" }
    }
}

@MainActor
final class FatCatLaunchAnimation {
    private var window: NSWindow?
    private var skipWindow: NSPanel?
    private var escapeMonitor: Any?

    func present(on screen: NSScreen, target: NSRect, completion: @escaping () -> Void) {
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let targetOffset = CGSize(width: target.midX - screen.frame.midX, height: screen.frame.midY - target.midY)
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false, screen: screen)
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true
        window.contentView = NSHostingView(rootView: LaunchOverlayView(reducedMotion: reduceMotion, targetOffset: targetOffset))
        window.orderFrontRegardless()
        self.window = window

        let skip = NSPanel(contentRect: NSRect(x: screen.frame.maxX - 94, y: screen.frame.maxY - 58, width: 78, height: 44), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        skip.level = .floating
        skip.isOpaque = false
        skip.backgroundColor = .clear
        skip.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        skip.contentView = NSHostingView(rootView: LaunchSkipView(skip: completion))
        skip.orderFrontRegardless()
        skipWindow = skip
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 53 else { return event }
            completion()
            return nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.45 : 2.6)) { completion() }
    }

    func dismiss() {
        guard let window else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.1 : 0.3
            window.animator().alphaValue = 0
        } completionHandler: { window.orderOut(nil) }
        skipWindow?.orderOut(nil)
        skipWindow = nil
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        self.window = nil
    }
}

@MainActor
final class OnboardingCoordinator {
    private var state = OnboardingState()
    private let store = OnboardingStore()
    private let launchAnimation = FatCatLaunchAnimation()
    private var card: OnboardingPanel?
    private var didFinishIntro = false
    var anchorProvider: (() -> NSRect)?
    var openProviderSetup: (() -> Void)?
    var testConnection: (((Bool) -> Void) -> Void)?
    var startUsefulTask: (() -> Void)?
    var onFinish: (() -> Void)?
    private var connectionStatus: String?
    private var connectionAttempt: UUID?

    var shouldPresent: Bool { store.shouldPresent }

    func start(on screen: NSScreen) {
        // Full-screen media and common sharing sessions should never receive the overlay.
        if frontmostWindowFills(screen) || isLikelyScreenSharing {
            showCard()
            return
        }
        launchAnimation.present(on: screen, target: anchorProvider?() ?? NSRect(x: screen.frame.midX - 75, y: screen.frame.midY - 75, width: 150, height: 150)) { [weak self] in self?.finishIntro() }
    }

    private var isLikelyScreenSharing: Bool {
        let knownSharingApps = ["zoom.us", "us.zoom.xos", "microsoft teams", "webex", "obs", "screen sharing"]
        return NSWorkspace.shared.runningApplications.contains { app in
            let identity = "\(app.localizedName ?? "") \(app.bundleIdentifier ?? "")".lowercased()
            return knownSharingApps.contains { identity.contains($0) }
        }
    }

    private func frontmostWindowFills(_ screen: NSScreen) -> Bool {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return false }
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        guard let bounds = windows.first(where: {
            ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid &&
            ($0[kCGWindowLayer as String] as? NSNumber)?.intValue == 0
        })?[kCGWindowBounds as String] as? NSDictionary,
        let frame = CGRect(dictionaryRepresentation: bounds) else { return false }
        return frame.width >= screen.frame.width * 0.98 && frame.height >= screen.frame.height * 0.98
    }

    private func finishIntro() {
        guard !didFinishIntro else { return }
        didFinishIntro = true
        launchAnimation.dismiss()
        showCard()
    }

    private func showCard() {
        let panel = card ?? OnboardingPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true; panel.level = .floating
        panel.contentView = NSHostingView(rootView: makeCard())
        panel.setContentSize(NSSize(width: 410, height: 330))
        if let anchor = anchorProvider?(), let visible = NSScreen.screens.first(where: { $0.frame.intersects(anchor) })?.visibleFrame {
            let preferredX = anchor.maxX + 14
            let x = min(max(preferredX, visible.minX + 12), visible.maxX - panel.frame.width - 12)
            let y = min(max(anchor.midY - panel.frame.height / 2, visible.minY + 12), visible.maxY - panel.frame.height - 12)
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        } else { panel.center() }
        panel.makeKeyAndOrderFront(nil)
        card = panel
    }

    private func makeCard() -> OnboardingCard {
        OnboardingCard(step: state.step, back: { [weak self] in self?.back() }, next: { [weak self] in self?.advance() }, skip: { [weak self] in self?.finish() }, providerSetup: { [weak self] in self?.openProviderSetup?() }, testConnection: { [weak self] in self?.beginConnectionTest() }, usefulTask: { [weak self] in self?.startUsefulTask?() }, connectionStatus: connectionStatus)
    }
    private func beginConnectionTest() {
        guard connectionStatus != "Waiting for Hermes…" else { return }
        let attempt = UUID()
        connectionAttempt = attempt
        connectionStatus = "Waiting for Hermes…"
        showCard()
        testConnection? { [weak self] succeeded in
            Task { @MainActor in self?.finishConnectionTest(attempt: attempt, succeeded: succeeded) }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
            self?.finishConnectionTest(attempt: attempt, succeeded: false)
        }
    }
    private func finishConnectionTest(attempt: UUID, succeeded: Bool) {
        guard connectionAttempt == attempt, state.step == .connection else { return }
        connectionAttempt = nil
        connectionStatus = succeeded ? "Connected to Hermes." : "Hermes could not complete the test. Check provider setup and try again."
        showCard()
        if succeeded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in self?.advance() }
        }
    }
    private func back() { state.goBack(); showCard() }
    private func advance() { state.advance(); state.isComplete ? finish() : showCard() }
    private func finish() { launchAnimation.dismiss(); card?.orderOut(nil); card = nil; store.markComplete(); onFinish?() }
}
