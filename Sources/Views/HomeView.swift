import SwiftUI

struct HomeView: View {
    @StateObject private var certManager = CertificateManager()
    @StateObject private var signingService: SigningService
    @State private var ipaFiles: [IPAFile] = []
    @State private var showFilePicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    init() {
        let certManager = CertificateManager()
        _certManager = StateObject(wrappedValue: certManager)
        _signingService = StateObject(wrappedValue: SigningService(certManager: certManager))
    }
    
    var body: some View {
        TabView {
            // تبويب التطبيقات
            NavigationView {
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack {
                        if ipaFiles.isEmpty {
                            EmptyStateView(showFilePicker: $showFilePicker)
                        } else {
                            IPAListView(
                                ipaFiles: $ipaFiles,
                                signingService: signingService
                            )
                        }
                    }
                }
                .navigationTitle("😈 Devil Sign")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showFilePicker = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.red)
                                .font(.title2)
                        }
                    }
                }
                .fileImporter(
                    isPresented: $showFilePicker,
                    allowedContentTypes: [.init(filenameExtension: "ipa")!],
                    allowsMultipleSelection: true
                ) { result in
                    handleFileImport(result: result)
                }
                .alert("خطأ", isPresented: $showError) {
                    Button("حسناً", role: .cancel) {}
                } message: {
                    Text(errorMessage)
                }
            }
            .tabItem {
                Label("التطبيقات", systemImage: "square.stack.3d.up.fill")
            }
            
            // تبويب الشهادات
            NavigationView {
                CertificateView()
                    .environmentObject(certManager)
            }
            .tabItem {
                Label("الشهادات", systemImage: "seal.fill")
            }
        }
        .accentColor(.red)
        .preferredColorScheme(.dark)
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    do {
                        let ipaFile = try await signingService.extractIPAInfo(from: url)
                        await MainActor.run {
                            ipaFiles.append(ipaFile)
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                }
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
