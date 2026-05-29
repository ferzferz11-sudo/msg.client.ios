import SwiftUI

struct ChatInputAreaView: View {
    @Binding var inputText: String
    let isInputFocused: FocusState<Bool>.Binding
    let onTextChanged: () -> Void
    let onSend: () -> Void
    let onImageTap: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(alignment: .bottom, spacing: 4) {
                TextField("Message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .focused(isInputFocused)
                    .lineLimit(1...5)
                    .onChange(of: inputText) { _, _ in
                        onTextChanged()
                    }

                Button(action: onImageTap) {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(20)

            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        inputText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color(.systemGray4)
                        : Color.purple
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}
