import Foundation

struct ArchiveRelativePathResolver: Sendable {
    let root: URL

    init(root: URL) {
        self.root = root.standardizedFileURL
    }

    func relativePath(for url: URL) -> String? {
        let rootComponents = root.standardizedFileURL.pathComponents
        let urlComponents = url.standardizedFileURL.pathComponents
        guard urlComponents.count > rootComponents.count else { return nil }
        guard Array(urlComponents.prefix(rootComponents.count)) == rootComponents else { return nil }
        return urlComponents.dropFirst(rootComponents.count).joined(separator: "/")
    }

    func url(for relativePath: String) -> URL {
        relativePath
            .split(separator: "/", omittingEmptySubsequences: true)
            .reduce(root) { partial, component in
                partial.appendingPathComponent(String(component))
            }
            .standardizedFileURL
    }
}
