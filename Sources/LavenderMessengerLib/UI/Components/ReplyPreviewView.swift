import SwiftUI

struct ReplyPreviewView: View {
    let message: Message
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(Color.purple)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text(message.user)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.purple)

                Text(message.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}
