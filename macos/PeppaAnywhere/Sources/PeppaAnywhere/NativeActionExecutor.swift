import AppKit
import ApplicationServices
import Foundation
import PeppaAnywhereCore

struct NativeExecutionResult: Equatable {
    let success: Bool
    let detail: String
}

@MainActor
final class NativeActionExecutor {
    func execute(_ proposal: NativeActionProposal, approval: NativeActionApproval) -> NativeExecutionResult {
        switch NativeActionPolicy.validate(proposal, approval: approval) {
        case .rejected: return NativeExecutionResult(success: false, detail: "Action was denied by Peppa's local permission policy.")
        case .needsApproval: return NativeExecutionResult(success: false, detail: "User approval is required before this action can run.")
        case .ready: break
        }

        switch proposal.action {
        case .readScreenContext, .inspectAccessibilityTree:
            guard AXIsProcessTrusted() else { return NativeExecutionResult(success: false, detail: "Accessibility permission is required.") }
            return NativeExecutionResult(success: true, detail: "Accessibility context is available locally.")
        case let .openApplication(bundleIdentifier):
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return NativeExecutionResult(success: false, detail: "Application was not found.") }
            return NativeExecutionResult(success: NSWorkspace.shared.open(url), detail: "Requested application launch.")
        case let .openFile(path):
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else { return NativeExecutionResult(success: false, detail: "File was not found.") }
            return NativeExecutionResult(success: NSWorkspace.shared.open(url), detail: "Requested file open.")
        case .highlightElement:
            return NativeExecutionResult(success: false, detail: "Element highlighting is not enabled until an accessibility target is verified.")
        case .typeText, .clickElement, .moveWindow:
            guard AXIsProcessTrusted() else { return NativeExecutionResult(success: false, detail: "Accessibility permission is required.") }
            return NativeExecutionResult(success: false, detail: "The target element must be revalidated immediately before mutation.")
        case let .runProcess(executable, arguments):
            guard FileManager.default.isExecutableFile(atPath: executable) else { return NativeExecutionResult(success: false, detail: "Executable was not found.") }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            do { try process.run(); process.waitUntilExit() } catch { return NativeExecutionResult(success: false, detail: error.localizedDescription) }
            return NativeExecutionResult(success: process.terminationStatus == 0, detail: "Process exited with status \(process.terminationStatus).")
        case .sendAppleEvent:
            return NativeExecutionResult(success: false, detail: "Apple Events require a separate explicit target permission.")
        }
    }

    func verify(_ proposal: NativeActionProposal, result: NativeExecutionResult) -> NativeExecutionResult {
        guard result.success else { return result }
        switch proposal.action {
        case let .openFile(path):
            return NativeExecutionResult(success: FileManager.default.fileExists(atPath: URL(fileURLWithPath: path).standardizedFileURL.path), detail: "Verified file still exists.")
        case let .openApplication(bundleIdentifier):
            return NativeExecutionResult(success: NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleIdentifier }, detail: "Verified application state.")
        default:
            return NativeExecutionResult(success: true, detail: "Native action completed; no independent state probe is available for this target.")
        }
    }
}
