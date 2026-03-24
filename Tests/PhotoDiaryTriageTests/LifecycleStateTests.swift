import Foundation
import Testing
@testable import PhotoDiaryTriage

@Test func lifecycleStateAllowsExpectedForwardTransitions() throws {
    #expect(try LifecycleState.discovered.transition(to: .selectedForImport) == .selectedForImport)
    #expect(try LifecycleState.selectedForImport.transition(to: .imported) == .imported)
    #expect(try LifecycleState.imported.transition(to: .verified) == .verified)
    #expect(try LifecycleState.verified.transition(to: .sourceCleanupPending) == .sourceCleanupPending)
    #expect(try LifecycleState.sourceCleanupPending.transition(to: .sourceCleaned) == .sourceCleaned)
}

@Test func lifecycleStateAllowsReturningSelectionToDiscovered() throws {
    #expect(try LifecycleState.selectedForImport.transition(to: .discovered) == .discovered)
}

@Test func lifecycleStateAllowsNoOpTransitionToSameState() throws {
    #expect(try LifecycleState.verified.transition(to: .verified) == .verified)
}

@Test func lifecycleStateRejectsInvalidTransitionsWithDescriptiveError() {
    var receivedError: Error?

    do {
        _ = try LifecycleState.discovered.transition(to: .sourceCleaned)
    } catch {
        receivedError = error
    }

    #expect(receivedError is LifecycleTransitionError)
    #expect((receivedError as? LocalizedError)?.errorDescription == "Invalid lifecycle transition from discovered to source_cleaned.")
}
