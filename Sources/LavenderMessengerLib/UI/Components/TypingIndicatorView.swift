import SwiftUI

struct TypingIndicatorView: View {
    let text: String

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(i) * 0.2),
                            value: text
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(.systemGray5))
            .cornerRadius(16)

            Spacer()
        }
        .padding(.horizontal, 12)
        .transition(.opacity)
    }
}
