//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftStreamingMarkdown
import SwiftUI

struct LLMChatView: View {
  @StateObject private var viewModel = LLMChatViewModel()
  @StateObject private var interactor = LLMChatInteractor()

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 16) {
          ForEach(viewModel.messages) { message in
            ChatMessageRow(message: message, config: interactor.markdownConfig)
              .id(message.id)
          }
        }
        .padding()
      }
      .defaultScrollAnchor(.bottom)
      .onChange(of: viewModel.messages.count) {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation {
          proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
      }
    }
    .background(Color.systemBackground)
    .safeAreaInset(edge: .bottom) {
      messageComposer
    }
    .task {
      await interactor.loadGreetingIfNeeded(into: viewModel)
    }
    .navigationTitle("LLM Chat")
    #if canImport(UIKit)
    .navigationBarTitleDisplayMode(.inline)
    #endif
  }

  private var messageComposer: some View {
    HStack(alignment: .bottom, spacing: 12) {
      TextField("Message", text: $viewModel.draft, axis: .vertical)
        .lineLimit(1...5)
        .textFieldStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 20))
        .onSubmit(send)

      Button(action: send) {
        Image(systemName: "arrow.up")
          .font(.headline)
          .foregroundStyle(.white)
          .frame(width: 38, height: 38)
          .background(.blue, in: .circle)
      }
      .buttonStyle(.plain)
      .disabled(!viewModel.canSend)
      .opacity(viewModel.canSend ? 1 : 0.4)
      .accessibilityLabel("Send message")
    }
    .padding(.horizontal)
    .padding(.vertical, 10)
    .background(.bar)
  }

  private func send() {
    Task { await interactor.send(into: viewModel) }
  }
}

private struct ChatMessageRow: View {
  let message: ChatMessage
  let config: MarkdownRenderConfig

  var body: some View {
    HStack {
      if case .user = message.content {
        Spacer(minLength: 48)
      }

      messageContent

      if case .assistant = message.content {
        Spacer(minLength: 48)
      }
    }
  }

  @ViewBuilder
  private var messageContent: some View {
    switch message.content {
    case .user(let text):
      Text(text)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.blue, in: .rect(cornerRadius: 18))
    case .assistant(let document):
      DocumentView(renderableDocument: document, config: config)
        .padding(14)
        .background(Color.secondary.opacity(0.12), in: .rect(cornerRadius: 18))
        .frame(maxWidth: 560, alignment: .leading)
    }
  }
}

#Preview {
  NavigationStack {
    LLMChatView()
  }
}
