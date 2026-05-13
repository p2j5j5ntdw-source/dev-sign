import Foundation
import ZIPFoundation
import Security

class SigningService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Double = 0
    @Published var statusMessage = ""
    
    private let certManager: CertificateManager
    
    init(certManager: CertificateManager) {
        self.certManager = certManager
    }
    
    // MARK: - استخراج معلومات IPA
    func extractIPAInfo(from url: URL) async throws -> IPAFile {
        await updateStatus("جاري قراءة الملف...", progress: 0.1)
        
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
    
    // MARK: - توقيع IPA
    func signIPA(
        ipa: IPAFile,
        newBundleID: String,
        newName: String,
        newVersion: String
    ) async throws {
        
        guard let cert = certManager.getValidCertificate() else {
            throw SigningError.noCertificate
        }
        
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        // فك الضغط
        await updateStatus("جاري فك ضغط IPA...", progress: 0.2)
        try FileManager.default.unzipItem(at: ipa.fileURL, to: tempDir)
        
        // البحث عن ملف .app
        let payloadDir = tempDir.appendingPathComponent("Payload")
        let apps = try FileManager.default.contentsOfDirectory(
            at: payloadDir,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "app" }
        
        guard let appDir = apps.first else {
            throw SigningError.invalidIPA
        }
        
        // تعديل Info.plist
        await updateStatus("جاري تعديل معلومات التطبيق...", progress: 0.4)
        try modifyPlist(
            appDir: appDir,
            bundleID: newBundleID,
            name: newName,
            version: newVersion
        )
        
        // إزالة التوقيع القديم
        await updateStatus("جاري إزالة التوقيع القديم...", progress: 0.5)
        try removeCodeSignature(appDir: appDir)
        
        // حقن Provisioning Profile
        await updateStatus("جاري إضافة Provisioning Profile...", progress: 0.6)
        try injectProvisioningProfile(
            appDir: appDir,
            provData: cert.provisioningData
        )
        
        // إعادة الضغط
        await updateStatus("جاري إعادة ضغط الملف...", progress: 0.75)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(newName).ipa")
        try FileManager.default.zipItem(
            at: tempDir,
            to: outputURL
        )
        
        // حفظ في Documents
        await updateStatus("جاري الحفظ...", progress: 0.9)
        try saveToDocuments(from: outputURL, name: newName)
        
        await updateStatus("تم بنجاح! 🎉", progress: 1.0)
    }
    
    // MARK: - Helper Functions
    
    private func extractPlistInfo(
        from url: URL
    ) async throws -> (String, String, String, Data?) {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        try FileManager.default.unzipItem(at: url, to: tempDir)
        
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
    
    private func modifyPlist(
        appDir: URL,
        bundleID: String,
        name: String,
        version: String
    ) throws {
        let plistURL = appDir.appendingPathComponent("Info.plist")
        var plist = try PropertyListSerialization.propertyList(
            from: try Data(contentsOf: plistURL),
            format: nil
        ) as? [String: Any] ?? [:]
        
        plist["CFBundleIdentifier"] = bundleID
        plist["CFBundleDisplayName"] = name
        plist["CFBundleName"] = name
        plist["CFBundleShortVersionString"] = version
        
        let newData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try newData.write(to: plistURL)
    }
    
    private func removeCodeSignature(appDir: URL) throws {
        let codeSignDir = appDir.appendingPathComponent("_CodeSignature")
        if FileManager.default.fileExists(atPath: codeSignDir.path) {
            try FileManager.default.removeItem(at: codeSignDir)
        }
    }
    
    private func injectProvisioningProfile(
        appDir: URL,
        provData: Data
    ) throws {
        let destURL = appDir.appendingPathComponent("embedded.mobileprovision")
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try provData.write(to: destURL)
    }
    
    private func saveToDocuments(from url: URL, name: String) throws {
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        let destURL = documentsDir.appendingPathComponent("\(name).ipa")
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        try FileManager.default.copyItem(at: url, to: destURL)
    }
    
    private func getFileSize(url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    @MainActor
    private func updateStatus(_ message: String, progress: Double) {
        self.statusMessage = message
        self.progress = progress
    }
}

// MARK: - Errors
enum SigningError: LocalizedError {
    case invalidIPA
    case signingFailed(String)
    case certificateError
    case noCertificate
    
    var errorDescription: String? {
        switch self {
        case .invalidIPA:
            return "ملف IPA غير صالح"
        case .signingFailed(let reason):
            return "فشل التوقيع: \(reason)"
        case .certificateError:
            return "خطأ في الشهادة"
        case .noCertificate:
            return "لا توجد شهادة صالحة، أضف شهادة أولاً"
        }
    }
}
