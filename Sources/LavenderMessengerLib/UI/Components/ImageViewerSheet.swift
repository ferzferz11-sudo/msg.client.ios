import SwiftUI

struct ImageViewerSheet: View {
    let imageUrl: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                AsyncImage(url: URL(string: imageUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty:
                        ProgressView()
                            .tint(.white)
                    case .failure:
                        VStack {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                            Text("Failed to load image")
                        }
                        .foregroundStyle(.white)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
    }
}
