import Foundation

struct IPAFile: Identifiable, Codable {
    let id: UUID
    var name: String
    var bundleID: String
    var version: String
    var fileURL: URL
    var iconData: Data?
    var fileSize: Int64
    var importDate: Date
    var isSigned: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        bundleID: String,
        version: String,
        fileURL: URL,
        iconData: Data? = nil,
        fileSize: Int64 = 0,
        importDate: Date = Date(),
        isSigned: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleID = bundleID
        self.version = version
        self.fileURL = fileURL
        self.iconData = iconData
        self.fileSize = fileSize
        self.importDate = importDate
        self.isSigned = isSigned
    }
    
    // حجم الملف بصيغة مقروءة
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}
