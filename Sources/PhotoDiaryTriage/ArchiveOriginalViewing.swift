import Foundation

struct ArchiveOriginalViewingService: Sendable {
    var requestDownload: @Sendable (URL) async throws -> Void = ArchiveFileProviderEvictor.requestDownload
    var wait: @Sendable () async throws -> Void = { try await Task.sleep(for: .milliseconds(250)) }
    var maximumReadinessChecks = 120
    var timeoutSeconds = 30.0

    func prepare(_ url: URL, policy: ArchiveByteReadPolicyContext) async throws {
        let generation = policy.generation
        guard policy.canRequestExplicitViewing(at: url) else {
            throw ArchiveFileVerification.failure("The selected original is outside the current Archive.")
        }
        try await ArchiveAsyncOperation.withTimeout(seconds: timeoutSeconds) {
            try Task.checkCancellation()
            guard policy.generation == generation else { throw CancellationError() }
            if policy.isAvailableForExplicitViewing(at: url) == false { try await requestDownload(url) }
            for _ in 0..<max(maximumReadinessChecks, 1) {
                try Task.checkCancellation()
                guard policy.generation == generation else {
                    throw ArchiveFileVerification.failure("Archive settings changed while the photo was downloading. Please select it again.")
                }
                if policy.isAvailableForExplicitViewing(at: url) { return }
                try await wait()
            }
            throw ArchiveFileVerification.failure("The original has not finished downloading. Check OneDrive and try Download to view again.")
        }
        try Task.checkCancellation()
        guard policy.grantExplicitViewing(at: url, generation: generation) else {
            throw ArchiveFileVerification.failure("The selected original is no longer available in this Archive.")
        }
    }
}

struct OriginalPreviewTaskKey: Hashable {
    let url: URL
    let blocked: Bool
}
