import Foundation
import WebKit

final class WebConfig {
    static let shared = WebConfig()

    let configuration: WKWebViewConfiguration

    private init() {
        let isTest = ProcessInfo.processInfo.environment["HEADLESSONE_TEST_API"] == "1"
        configuration = WKWebViewConfiguration()
        if isTest {
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
        } else {
            configuration.websiteDataStore = WKWebsiteDataStore.default()
        }
        configuration.setURLSchemeHandler(FixtureSchemeHandler(), forURLScheme: "fixture")
    }
}
