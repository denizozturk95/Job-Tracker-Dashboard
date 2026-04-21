import Foundation

enum AppGroup {
    static let identifier = "group.com.deniz.jobtracker"
    static let iCloudContainer = "iCloud.com.deniz.jobtracker"
    static let pendingIngestKey = "pendingIngestURLs"
}

enum BGTaskID {
    static let ghostingScan = "com.deniz.jobtracker.ghostingScan"
    static let weeklyDigest = "com.deniz.jobtracker.weeklyDigest"
}
