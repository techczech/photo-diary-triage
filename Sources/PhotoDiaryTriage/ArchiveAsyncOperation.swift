import Foundation

private final class ArchiveAsyncCompletion<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var result: Result<Value, Error>?
    func install(_ continuation: CheckedContinuation<Value, Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }
    func finish(_ result: Result<Value, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}

enum ArchiveAsyncOperation {
    static func callback<Value>(_ begin: @escaping (@escaping (Result<Value, Error>) -> Void) -> Void) async throws -> Value {
        let completion = ArchiveAsyncCompletion<Value>()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                completion.install(continuation)
                begin { completion.finish($0) }
            }
        } onCancel: {
            completion.finish(.failure(CancellationError()))
        }
    }

    // Unstructured workers let the deadline return even if an injected transport does
    // not cooperate with cancellation. Production callbacks use the cancellable bridge.
    static func withTimeout<Value>(seconds: Double, operation: @escaping @Sendable () async throws -> Value) async throws -> Value {
        try Task.checkCancellation()
        let completion = ArchiveAsyncCompletion<Value>()
        let worker = Task {
            do { completion.finish(.success(try await operation())) }
            catch { completion.finish(.failure(error)) }
        }
        let timer = Task {
            do {
                try await Task.sleep(for: .seconds(max(seconds, 0)))
                completion.finish(.failure(ArchiveFileVerification.failure("The Archive request timed out. Check OneDrive and try again.")))
                worker.cancel()
            } catch { }
        }
        defer { worker.cancel(); timer.cancel() }
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { completion.install($0) }
        } onCancel: {
            completion.finish(.failure(CancellationError()))
            worker.cancel()
            timer.cancel()
        }
    }
}
