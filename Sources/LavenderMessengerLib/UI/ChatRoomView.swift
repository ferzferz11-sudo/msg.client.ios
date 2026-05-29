import SwiftUI

struct ChatRoomView: View {
    let chatId: String
    let chatName: String
    let username: String

    @StateObject private var viewModel: ChatViewModel
    @State private var showChatInfo: Bool = false
    @FocusState private var isInputFocused: Bool

    init(chatId: String, chatName: String, username: String) {
        self.chatId = chatId
        self.chatName = chatName
        self.username = username
        _viewModel = StateObject(wrappedValue: ChatViewModel(roomId: chatId))
    }

    var body: some View {
        VStack(spacing: 0) {
            messagesScrollView

            if !viewModel.typingText.isEmpty {
                TypingIndicatorView(text: viewModel.typingText)
            }

            if let replyMsg = viewModel.replyingToMessage {
                ReplyPreviewView(message: replyMsg, onCancel: viewModel.cancelReply)
            }

            ChatInputAreaView(
                inputText: $viewModel.inputText,
                isInputFocused: $isInputFocused,
                onTextChanged: viewModel.onInputTextChanged,
                onSend: viewModel.sendMessage,
                onImageTap: { /* Image picker */ }
            )
        }
        .navigationTitle(chatName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showChatInfo = true }) {
                    Image(systemName: "info.circle")
                }
            }
        }
        .onAppear {
            viewModel.setCurrentUsername(username)
            viewModel.markAsRead()
        }
        .onDisappear {
            viewModel.saveDraft()
        }
        .sheet(isPresented: $showChatInfo) {
            ChatInfoView(chatId: chatId, chatName: chatName, username: username)
        }
        .sheet(isPresented: $viewModel.showImageViewer) {
            if !viewModel.viewerImageUrl.isEmpty {
                ImageViewerSheet(imageUrl: viewModel.viewerImageUrl)
            }
        }
    }

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding()
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(
                            message: message,
                            isCurrentUser: message.user == username,
                            onReply: { viewModel.startReply(to: message) },
                            onReaction: { viewModel.setReaction(messageId: message.id, emoji: $0) },
                            onDelete: { viewModel.deleteMessage(message) },
                            onImageTap: { url in
                                viewModel.viewerImageUrl = url
                                viewModel.showImageViewer = true
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}
