import Cocoa
import WebKit

guard CommandLine.arguments.count == 4 else {
    fputs("usage: capture-fatcat-avatar.swift <avatar-html> <animation> <output-png>\n", stderr)
    exit(EXIT_FAILURE)
}

let avatarURL = URL(fileURLWithPath: CommandLine.arguments[1])
let animation = CommandLine.arguments[2]
let outputURL = URL(fileURLWithPath: CommandLine.arguments[3])

final class CaptureDelegate: NSObject, WKNavigationDelegate {
    let animation: String
    let outputURL: URL

    init(animation: String, outputURL: URL) {
        self.animation = animation
        self.outputURL = outputURL
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let escaped = try! String(data: JSONSerialization.data(withJSONObject: animation), encoding: .utf8)!
        webView.evaluateJavaScript("window.fatCatAvatar?.setAnimation(\(escaped));") { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                webView.takeSnapshot(with: nil) { image, error in
                    guard let image, let representation = NSBitmapImageRep(cgImage: image) as NSBitmapImageRep?,
                          let data = representation.representation(using: .png, properties: [:]) else {
                        fputs("avatar snapshot failed: \(error?.localizedDescription ?? \"unknown error\")\n", stderr)
                        NSApp.terminate(nil)
                        return
                    }
                    do {
                        try data.write(to: self.outputURL)
                    } catch {
                        fputs("avatar snapshot write failed: \(error.localizedDescription)\n", stderr)
                    }
                    NSApp.terminate(nil)
                }
            }
        }
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 320), styleMask: .borderless, backing: .buffered, defer: false)
window.isOpaque = false
window.backgroundColor = .clear
window.hasShadow = false

let webView = WKWebView(frame: window.contentView!.bounds)
webView.setValue(false, forKey: "drawsBackground")
webView.underPageBackgroundColor = .clear
webView.navigationDelegate = CaptureDelegate(animation: animation, outputURL: outputURL)
window.contentView = webView
window.orderFrontRegardless()
webView.loadFileURL(avatarURL, allowingReadAccessTo: avatarURL.deletingLastPathComponent())
application.run()
