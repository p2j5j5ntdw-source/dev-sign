import SwiftUI
import UniformTypeIdentifiers

struct CertificateView: View {
    @EnvironmentObject var certManager: CertificateManager
    @State private var showAddCert = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                if certManager.certificates.isEmpty {
                    EmptyCertView(showAddCert: $showAddCert)
                } else {
                    CertListView(
                        certificates: $certManager.certificates,
                        showAddCert: $showAddCert
                    )
                }
            }
        }
        .navigationTitle("الشهادات")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddCert = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showAddCert) {
            AddCertificateView(certManager: certManager)
        }
        .preferredColorScheme(.dark)
    }
}

// قائمة الشهادات
struct CertListView: View {
    @Binding var certificates: [Certificate]
    @Binding var showAddCert: Bool
    
    var body: some View {
        List {
            ForEach(certificates) { cert in
                CertRowView(cert: cert)
                    .listRowBackground(Color.gray.opacity(0.15))
            }
            .onDelete { indexSet in
                certificates.remove(atOffsets: indexSet)
            }
        }
        .scrollContentBackground(.hidden)
    }
}

// صف شهادة واحدة
struct CertRowView: View {
    let cert: Certificate
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "seal.fill")
                .font(.largeTitle)
                .foregroundColor(cert.isValid ? .green : .red)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(cert.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(cert.teamID.isEmpty ? "No Team ID" : cert.teamID)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let days = cert.daysRemaining {
                    Text(days > 0 ? "تنتهي بعد \(days) يوم" : "منتهية")
                        .font(.caption2)
                        .foregroundColor(days > 30 ? .green : .orange)
                }
            }
            
            Spacer()
            
            Image(systemName: cert.isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(cert.isValid ? .green : .red)
        }
        .padding(.vertical, 6)
    }
}

// شاشة فارغة
struct EmptyCertView: View {
    @Binding var showAddCert: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "seal.fill")
                .font(.system(size: 70))
                .foregroundColor(.red)
            
            Text("لا توجد شهادات")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("أضف شهادتك للبدء في التوقيع")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button {
                showAddCert = true
            } label: {
                Label("إضافة شهادة", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
    }
}

// شاشة إضافة شهادة
struct AddCertificateView: View {
    @ObservedObject var certManager: CertificateManager
    @Environment(\.dismiss) var dismiss
    @State private var certName = ""
    @State private var p12Password = ""
    @State private var teamID = ""
    @State private var showP12Picker = false
    @State private var showProvPicker = false
    @State private var p12Data: Data?
    @State private var provData: Data?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var canSave: Bool {
        !certName.isEmpty && p12Data != nil && provData != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // اسم الشهادة
                        GroupBox {
                            TextField("مثال: شهادتي الشخصية", text: $certName)
                                .foregroundColor(.white)
                        } label: {
                            Label("اسم الشهادة", systemImage: "tag")
                                .foregroundColor(.red)
                        }
                        .backgroundStyle(Color.gray.opacity(0.15))
                        
                        // ملف P12
                        GroupBox {
                            Button {
                                showP12Picker = true
                            } label: {
                                HStack {
                                    Image(systemName: p12Data != nil ? "checkmark.circle.fill" : "arrow.up.doc.fill")
                                        .foregroundColor(p12Data != nil ? .green : .red)
                                    Text(p12Data != nil ? "تم رفع ملف P12 ✅" : "اختر ملف .p12")
                                        .foregroundColor(p12Data != nil ? .green : .white)
                                    Spacer()
                                }
                            }
                            
                            Divider().background(Color.gray)
                            
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.gray)
                                SecureField("كلمة مرور P12", text: $p12Password)
                                    .foregroundColor(.white)
                            }
                        } label: {
                            Label("شهادة P12", systemImage: "key.fill")
                                .foregroundColor(.red)
                        }
                        .backgroundStyle(Color.gray.opacity(0.15))
                        
                        // ملف Provisioning Profile
                        GroupBox {
                            Button {
                                showProvPicker = true
                            } label: {
                                HStack {
                                    Image(systemName: provData != nil ? "checkmark.circle.fill" : "arrow.up.doc.fill")
                                        .foregroundColor(provData != nil ? .green : .red)
                                    Text(provData != nil ? "تم رفع Provisioning Profile ✅" : "اختر ملف .mobileprovision")
                                        .foregroundColor(provData != nil ? .green : .white)
                                    Spacer()
                                }
                            }
                        } label: {
                            Label("Provisioning Profile", systemImage: "doc.badge.gearshape")
                                .foregroundColor(.red)
                        }
                        .backgroundStyle(Color.gray.opacity(0.15))
                        
                        // Team ID
                        GroupBox {
                            TextField("مثال: ABC1234567", text: $teamID)
                                .foregroundColor(.white)
                        } label: {
                            Label("Team ID (اختياري)", systemImage: "person.2.fill")
                                .foregroundColor(.red)
                        }
                        .backgroundStyle(Color.gray.opacity(0.15))
                        
                        // زر الحفظ
                        Button {
                            saveCertificate()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.down.fill")
                                Text("حفظ الشهادة")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSave ? Color.red : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(!canSave)
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("إضافة شهادة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إلغاء") { dismiss() }
                        .foregroundColor(.red)
                }
            }
            .fileImporter(
                isPresented: $showP12Picker,
                allowedContentTypes: [UTType(filenameExtension: "p12") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    p12Data = try? Data(contentsOf: url)
                case .failure:
                    break
                }
            }
            .fileImporter(
                isPresented: $showProvPicker,
                allowedContentTypes: [UTType(filenameExtension: "mobileprovision") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    guard url.startAccessingSecurityScopedResource() else { return }
                    defer { url.stopAccessingSecurityScopedResource() }
                    provData = try? Data(contentsOf: url)
                case .failure:
                    break
                }
            }
            .alert("خطأ", isPresented: $showError) {
                Button("حسناً", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func saveCertificate() {
        guard let p12 = p12Data, let prov = provData else { return }
        
        let cert = Certificate(
            name: certName,
            p12Data: p12,
            password: p12Password,
            provisioningData: prov,
            teamID: teamID
        )
        
        certManager.addCertificate(cert)
        dismiss()
    }
}
