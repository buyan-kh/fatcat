import Testing
@testable import PeppaAnywhereCore

struct NativeActionTests {
    @Test func riskPolicyKeepsReadOnlyContextLowRisk() {
        #expect(NativeActionPolicy.risk(for: .readScreenContext) == .low)
        #expect(NativeActionPolicy.risk(for: .inspectAccessibilityTree) == .low)
        #expect(NativeActionPolicy.risk(for: .openFile(path: "/tmp/example.txt")) == .low)
    }

    @Test func riskPolicyRequiresApprovalForMutation() {
        #expect(NativeActionPolicy.risk(for: .typeText("hello")) == .medium)
        #expect(NativeActionPolicy.risk(for: .clickElement(identifier: "save")) == .medium)
        #expect(NativeActionPolicy.risk(for: .runProcess(executable: "/bin/echo", arguments: ["hello"])) == .high)
        #expect(NativeActionPolicy.requiresApproval(for: .typeText("hello")))
        #expect(NativeActionPolicy.requiresApproval(for: .runProcess(executable: "/bin/echo", arguments: ["hello"])))
    }

    @Test func unknownProposalsAreRejectedBeforeExecution() {
        let proposal = NativeActionProposal(id: "a1", action: .typeText("hello"), reason: "test")
        #expect(NativeActionPolicy.validate(proposal, approval: .denied) == .rejected)
        #expect(NativeActionPolicy.validate(proposal, approval: .approved) == .ready)
    }
}
