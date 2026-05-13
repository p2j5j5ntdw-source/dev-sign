import Foundation

struct Certificate: Identifiable, Codable {
    let id: UUID
    var name: String
    var p12Data: Data
    var password: String
    var provisioningData: Data
    var expiryDate: Date?
    var teamID: String
    var importDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        p12Data: Data,
        password: String,
        provisioningData: Data,
        expiryDate: Date? = nil,
        teamID: String = "",
        importDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.p12Data = p12Data
        self.password = password
        self.provisioningData = provisioningData
        self.expiryDate = expiryDate
        self.teamID = teamID
        self.importDate = importDate
    }
    
    // هل الشهادة صالحة؟
    var isValid: Bool {
        guard let expiry = expiryDate else { return true }
        return expiry > Date()
    }
    
    // كم يوم باقي
    var daysRemaining: Int? {
        guard let expiry = expiryDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expiry).day
    }
}
