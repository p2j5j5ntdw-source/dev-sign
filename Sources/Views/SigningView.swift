import SwiftUI

struct SigningView: View {
    let ipa: IPAFile
    @ObservedObject var signingService: SigningService
    @Environment(\.dismiss) var dismiss
    @State private var bundleID: String = ""
    @State private var appName: String = ""
    @State private var version: String = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // أيقونة التطبيق
                        AppIconView(iconData: ipa.iconData)
                        
                        // معلومات قابلة للتعديل
                        GroupBox {
                            VStack(spacing: 14) {
                                InfoFieldView(
                                    title: "اسم التطبيق",
                                    placeholder: ipa.name,
                                    text: $appName
                                )
                                
                                Divider().background(Color.gray)
                                
                                InfoFieldView(
                                    title: "Bundle ID",
                                    placeholder: ipa.bundleID,
                                    text: $bundleID
                                )
                                
                                Divider().background(Color.gray)
                                
                                InfoFieldView(
                                    title: "الإصدار",
                                    placeholder: ipa.version,
                                    text: $version
                                )
                            }
                        } label: {
                            Label("تفاصيل التطبيق", systemImage: "info.circle")
                                .foregroundColor(.red)
                        }
                        .backgroundStyle(Color.gray.opacity(0.15))
                        
                        // حالة التوقيع
                        if signingService.isProcessing {
                            ProcessingView(
                                progress: signingService.progress,
                                message: signingService.statusMessage
                            )
                        }
                        
                        // زر التوقيع
                        Button {
                            Task { await signIPA() }
                        } label: {
                            HStack {
                                Image(systemName: "signature")
                                Text("وقّع التطبيق")
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(signingService.isProcessing ? Color.gray : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(signingService.isProcessing)
                        .padding(.horizontal)
                        
                    }
                    .padding()
                }
            }
            .navigationTitle(ipa.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("إغلاق") { dismiss() }
                        .foregroundColor(.red)
                }
            }
            .alert("تم التوقيع بنجاح! 🎉", isPresented: $showSuccess) {
                Button("حسناً") { dismiss() }
            } message: {
                Text("تم توقيع \(ipa.name) بنجاح")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            bundleID = ipa.bundleID
            appName = ipa.name
            version = ipa.version
        }
    }
    
    private func signIPA() async {
        do {
            try await signingService.signIPA(
                ipa: ipa,
                newBundleID: bundleID,
                newName: appName,
                newVersion: version
            )
            await MainActor.run { showSuccess = true }
        } catch {
            await MainActor.run {
                signingService.statusMessage = error.localizedDescription
            }
        }
    }
}

// أيقونة التطبيق
struct AppIconView: View {
    let iconData: Data?
    
    var body: some View {
        Group {
            if let data = iconData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.red)
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .red.opacity(0.5), radius: 10)
    }
}

// حقل معلومات
struct InfoFieldView: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(width: 100, alignment: .leading)
            
            TextField(placeholder, text: $text)
                .font(.subheadline)
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}

// شاشة المعالجة
struct ProcessingView: View {
    let progress: Double
    let message: String
    
    var body: some View {
        VStack(spacing: 10) {
            ProgressView(value: progress)
                .tint(.red)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}
