import SwiftUI

struct DownloadView: View {
    let fileURL: URL
    let format: ExportFormat
    let onComplete: () -> Void
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("File Ready").font(.system(size: 24, weight: .semibold))
            Text(fileURL.lastPathComponent).font(.system(size: 14)).foregroundColor(.secondary)
            Spacer()
            Button { showShareSheet = true } label: {
                Text("Download")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: 50)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            Button("Done") { onComplete() }.padding(.bottom, 20)
        }
        .padding()
        .sheet(isPresented: $showShareSheet) { ShareSheet(items: [fileURL]) }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
