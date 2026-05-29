import Foundation

public enum ClientVersion {
    public static var string: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0"
    }
}
