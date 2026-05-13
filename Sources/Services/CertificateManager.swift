import Foundation
import Security

class CertificateManager: ObservableObject {
    @Published var certificates: [Certificate] = []
    
    private let saveKey = "devil_sign_certificates"
    
    init() {
        loadCertificates()
    }
    
    // MARK: - إضافة شهادة
    func addCertificate(_ cert: Certificate) {
        certificates.append(cert)
        saveCertificates()
    }
    
    // MARK: - حذف شهادة
    func removeCertificate(id: UUID) {
        certificates.removeAll { $0.id == id }
        saveCertificates()
    }
    
    // MARK: - حفظ في Keychain
    private func saveCertificates() {
        guard let data = try? JSONEncoder().encode(certificates) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: saveKey,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    // MARK: - تحميل من Keychain
    private func loadCertificates() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: saveKey,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        SecItemCopyMatching(query as CFDictionary, &result)
        
        if let data = result as? Data,
           let certs = try? JSONDecoder().decode([Certificate].self, from: data) {
            certificates = certs
        }
    }
    
    // MARK: - الحصول على شهادة للتوقيع
    func getValidCertificate() -> Certificate? {
        return certificates.first { $0.isValid }
    }
}
