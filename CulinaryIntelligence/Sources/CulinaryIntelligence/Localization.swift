import Foundation

extension String {
    /// A string from this package's own catalog. Everything the package says, to a model or to
    /// the cook, is written there rather than in the app's.
    nonisolated init(culinary key: String.LocalizationValue) {
        self.init(localized: key, bundle: .module)
    }
}

extension LocalizedStringResource {
    /// A key in this package's catalog, for text the app shows as it stands.
    nonisolated init(culinary key: String.LocalizationValue) {
        self.init(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
