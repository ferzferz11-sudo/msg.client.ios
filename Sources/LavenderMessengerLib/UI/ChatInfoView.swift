import SwiftUI

struct ChatInfoView: View {
    let chatId: String
    let chatName: String
    let username: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Circle()
                            .fill(Color.purple.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay {
                                Text(String(chatName.prefix(1)).uppercased())
                                    .font(.title.weight(.bold))
                                    .foregroundStyle(.purple)
                            }

                        VStack(alignment: .leading) {
                            Text(chatName)
                                .font(.title3.weight(.semibold))
                            Text("Chat ID: \(chatId.prefix(8))...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Actions") {
                    Button(action: {}) {
                        Label("Clear History", systemImage: "trash")
                    }

                    Button(action: {}) {
                        Label("Export Chat", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive, action: {}) {
                        Label("Delete Chat", systemImage: "xmark.circle")
                    }
                }
            }
            .navigationTitle("Chat Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
