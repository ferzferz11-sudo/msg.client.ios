import SwiftUI

struct MessageBubbleView: View {
    let message: Message
    let isCurrentUser: Bool
    let onReply: () -> Void
    let onReaction: (String) -> Void
    let onDelete: () -> Void
    let onImageTap: (String) -> Void

    @State private var showReactionPicker: Bool = false

    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 50) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isCurrentUser {
                    Text(message.user)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }

                replyReferenceView
                messageContentView
                reactionsView
                metadataView
            }
            .contextMenu { contextMenuItems }
            .onLongPressGesture { showReactionPicker = true }
            .sheet(isPresented: $showReactionPicker) {
                ReactionPickerView(onSelect: { emoji in
                    onReaction(emoji)
                    showReactionPicker = false
                })
            }

            if !isCurrentUser { Spacer(minLength: 50) }
        }
    }

    @ViewBuilder
    private var replyReferenceView: some View {
        if !message.repliedToText.isEmpty {
            HStack {
                Rectangle()
                    .fill(isCurrentUser ? Color.white.opacity(0.5) : Color.purple.opacity(0.3))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(message.repliedToUser)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isCurrentUser ? .white.opacity(0.8) : .purple)
                    Text(message.repliedToText)
                        .font(.caption2)
                        .foregroundStyle(isCurrentUser ? .white.opacity(0.6) : .secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((isCurrentUser ? Color.white : Color.purple).opacity(0.15))
            .cornerRadius(8)
        }
    }

    @ViewBuilder
    private var messageContentView: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !message.imageUrl.isEmpty {
                AsyncImage(url: URL(string: message.imageUrl)) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 200, height: 150)
                            .overlay(ProgressView())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: 250)
                            .cornerRadius(12)
                            .clipped()
                            .onTapGesture { onImageTap(message.imageUrl) }
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.red.opacity(0.1))
                            .frame(width: 200, height: 100)
                            .overlay {
                                VStack {
                                    Image(systemName: "exclamationmark.triangle")
                                    Text("Failed to load")
                                        .font(.caption)
                                }
                                .foregroundStyle(.red)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            }

            if !message.text.isEmpty {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isCurrentUser ? .white : .primary)
            }

            if message.hasVoice {
                HStack {
                    Image(systemName: "waveform")
                    Text("\(message.duration)s")
                        .font(.caption)
                }
                .foregroundStyle(isCurrentUser ? .white : .purple)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            isCurrentUser ? Color.purple.gradient : Color(.systemGray5).gradient
        )
        .cornerRadius(18, corners: isCurrentUser ? [.topLeft, .topRight, .bottomLeft] : [.topLeft, .topRight, .bottomRight])
    }

    @ViewBuilder
    private var reactionsView: some View {
        if !message.reactions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(message.reactions) { reaction in
                        Button(action: { onReaction(reaction.emoji) }) {
                            HStack(spacing: 2) {
                                Text(reaction.emoji)
                                let count = message.reactions.filter { $0.emoji == reaction.emoji }.count
                                if count > 1 {
                                    Text("\(count)")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var metadataView: some View {
        HStack(spacing: 4) {
            if message.edited {
                Text("(edited)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(formatTimestamp(message.timestamp))
                .font(.caption2)
                .foregroundStyle(.secondary)

            if isCurrentUser {
                Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.caption2)
                    .foregroundStyle(message.isRead ? .blue : .secondary.opacity(0.5))
            }
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        Button(action: onReply) {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
        Button(action: { onReaction("👍") }) {
            Label("Like", systemImage: "hand.thumbsup")
        }
        if isCurrentUser {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd MMM HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
