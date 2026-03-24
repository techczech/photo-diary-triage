import Foundation

struct AppRelease {
    let version: String
    let build: String
    let featureSlug: String

    static var current: AppRelease {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let featureSlug = bundle.object(forInfoDictionaryKey: "PDTLatestFeatureSlug") as? String

        return AppRelease(
            version: version ?? "dev",
            build: build ?? "0",
            featureSlug: featureSlug ?? "unversioned"
        )
    }

    var displayString: String {
        "v\(version) · \(featureSlug)"
    }
}
