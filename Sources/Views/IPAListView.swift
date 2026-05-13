import SwiftUI

struct IPAListView: View {
    @Binding var ipaFiles: [IPAFile]
    @ObservedObject var signingService: SigningService
    @State private var selectedIPA: IPAFile?
    @State private var showSigningView = false
    
    var body: some View {
        List {
            ForEach(ipaFiles) { ipa in
                IPARowView(ipa: ipa)
                    .listRowBackground(Color.gray.opacity(0.15))
                    .onTapGesture {
                        selectedIPA = ipa
                        showSigningView = true
                    }
            }
            .onDelete { indexSet in
                ipaFiles.remove(atOffsets: indexSet)
            }
        }
        .scrollContentBackground(.hidden)
        .sheet(isPresented: $showSigningView) {
            if let ipa = selectedIPA {
                SigningView(ipa: ipa, signingService: signingService)
            }
        }
    }
}

// صف واحد في القائمة
struct IPARowView: View {
    let ipa: IPAFile
    
    var body: some View {
        HStack(spacing: 14) {
            // أيقونة التطبيق
            Group {
                if let iconData = ipa.iconData,
                   let uiImage = UIImage(data: iconData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "app.fill")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                }
            }
            .frame(width: 55, height: 55)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // معلومات التطبيق
            VStack(alignment: .leading, spacing: 4) {
                Text(ipa.name)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(ipa.bundleID)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                HStack {
                    Text("v\(ipa.version)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    Text("•")
                        .foregroundColor(.gray)
                    
                    Text(ipa.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // حالة التوقيع
            VStack {
                Image(systemName: ipa.isSigned ? "checkmark.seal.fill" : "seal")
                    .foregroundColor(ipa.isSigned ? .green : .red)
                    .font(.title3)
                
                Text(ipa.isSigned ? "موقّع" : "غير موقّع")
                    .font(.caption2)
                    .foregroundColor(ipa.isSigned ? .green : .red)
            }
        }
        .padding(.vertical, 6)
    }
}
