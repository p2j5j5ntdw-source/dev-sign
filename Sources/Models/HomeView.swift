import SwiftUI

struct HomeView: View {
    @StateObject private var signingService = SigningService()
    @State private var ipaFiles: [IPAFile] = []
    @State private var showFilePicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // خلفية داكنة
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
            .navigationBarTitleDisplayMode(.large)
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

// شاشة فارغة
struct EmptyStateView: View {
    @Binding var showFilePicker: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "flame.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)
            
            Text("Devil Sign")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("استورد ملف IPA للبدء")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Button {
                showFilePicker = true
            } label: {
                Label("استورد IPA", systemImage: "plus.circle.fill")
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
