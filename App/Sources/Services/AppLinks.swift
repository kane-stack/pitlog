import Foundation

/// The web pages the app links to. The only place that knows these addresses.
///
/// The privacy policy address is a placeholder until the real page is online (see `docs/privacy.md`). Replace
/// it here and in App Store Connect. Opening a link hands over to the browser; the app itself makes no
/// network request.
enum AppLinks {
    static let privacyPolicy = URL(string: "https://example.com/pitlog/privacy")
    /// Apple's standard license agreement, used for the subscription terms.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
}
