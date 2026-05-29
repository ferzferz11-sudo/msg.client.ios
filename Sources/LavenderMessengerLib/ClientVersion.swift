import Foundation

enum ClientVersion {
    static var string: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
    }
}
