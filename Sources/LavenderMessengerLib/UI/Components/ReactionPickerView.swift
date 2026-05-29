import SwiftUI

struct ReactionPickerView: View {
    let onSelect: (String) -> Void

    private let emojis = ["👍", "👎", "❤️", "😂", "😮", "😢", "🔥", "🎉", "🙏", "💪"]

    var body: some View {
        VStack(spacing: 20) {
            Text("React")
                .font(.headline)
                .padding(.top)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(action: { onSelect(emoji) }) {
                        Text(emoji)
                            .font(.system(size: 32))
                    }
                }
            }
            .padding()
        }
        .presentationDetents([.height(180)])
    }
}
