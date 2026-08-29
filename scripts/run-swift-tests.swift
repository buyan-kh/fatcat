import Darwin
import Foundation
import Testing

// SwiftPM under Command Line Tools (no Xcode) builds test bundles but silently
// skips execution because the XCTest runner is absent. This runner loads the
// built swift-testing bundle and drives it through the Testing entry point.
@main
struct FatCatSwiftTestRunner {
    static func main() async {
        guard let bundlePath = ProcessInfo.processInfo.environment["FATCAT_TEST_BUNDLE"] else {
            fputs("Set FATCAT_TEST_BUNDLE to the built test bundle binary path.\n", stderr)
            exit(2)
        }
        guard dlopen(bundlePath, RTLD_NOW) != nil else {
            let message = dlerror().map { String(cString: $0) } ?? "unknown dlopen failure"
            fputs("Could not load test bundle: \(message)\n", stderr)
            exit(2)
        }
        await __swiftPMEntryPoint(passing: nil) as Never
    }
}
