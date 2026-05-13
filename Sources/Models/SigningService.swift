import Foundation
import ZIPFoundation

class SigningService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    
    // استخراج معلومات IPA
    func extractIPAInfo(from url: URL) async throws -> IPAFile {
        statusMessage = "جاري قراءة الملف..."
        
        let fileSize = try getFileSize(url: url)
        let (bundleID, version, name, iconData) = try await extractPlistInfo(from: url)
        
        return IPAFile(
            name: name,
            bundleID: bundleID,
            version: version,
            fileURL: url,
            iconData: iconData,
            fileSize: fileSize
        )
    }
    
    // قراءة معلومات Info.plist من داخل IPA
    private func extractPlistInfo(from url: URL) async throws -> (String, String, String, Data?) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // فك ضغط IPA (هو في الأصل ZIP)
        try FileManager.default.unzipItem(at: url, to: tempDir)
        
        // البحث عن Info.plist
        let payloadDir = tempDir.appendingPathComponent("Payload")
        let apps = try FileManager.default.contentsOfDirectory(
            at: payloadDir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "app" }
        
        guard let appDir = apps.first else {
            throw SigningError.invalidIPA
        }
        
        let plistURL = appDir.appendingPathComponent("Info.plist")
        let plistData = try Data(contentsOf: plistURL)
        let plist = try PropertyListSerialization.propertyList(
            from: plistData,
            format: nil
        ) as? [String: Any] ?? [:]
        
        let bundleID = plist["CFBundleIdentifier"] as? String ?? "unknown"
        let version = plist["CFBundleShortVersionString"] as? String ?? "1.0"
        let name = plist["CFBundleDisplayName"] as? String
            ?? plist["CFBundleName"] as? String
            ?? appDir.deletingPathExtension().lastPathComponent
        
        // أيقونة التطبيق
        var iconData: Data? = nil
        if let iconFiles = plist["CFBundleIcons"] as? [String: Any],
           let primaryIcon = iconFiles["CFBundlePrimaryIcon"] as? [String: Any],
           let iconNames = primaryIcon["CFBundleIconFiles"] as? [String],
           let iconName = iconNames.last {
            let iconURL = appDir.appendingPathComponent("\(iconName).png")
            iconData = try? Data(contentsOf: iconURL)
        }
        
        return (bundleID, version, name, iconData)
    }
    
    private func getFileSize(url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
}

// أخطاء التوقيع
enum SigningError: LocalizedError {
    case invalidIPA
    case signingFailed(String)
    case certificateError
    
    var errorDescription: String? {
        switch self {
        case .invalidIPA:
            return "ملف IPA غير صالح"
        case .signingFailed(let reason):
            return "فشل التوقيع: \(reason)"
        case .certificateError:
            return "خطأ في الشهادة"
        }
    }
}
