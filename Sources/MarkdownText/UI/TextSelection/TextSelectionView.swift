//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftUI

/// A modal that presents the full document as selectable, uneditable text so
/// the user can select more than the tapped block. Presented by `DocumentView`
/// when the built-in "Select more text" edit-menu action is invoked.
struct TextSelectionView: View {
  let text: String
  let onDismiss: () -> Void

  var body: some View {
    VStack(spacing: 14) {
      TextSelectionHeader(title: String.selectMoreTextLabel, onDismiss: onDismiss)
      SelectableTextView(text: text)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 18)
    }
    .background(Color.Theme.Background.Page.Chat.Flat.ignoresSafeArea())
  }
}

private struct TextSelectionHeader: View {
  let title: String
  let onDismiss: () -> Void

  var body: some View {
    ZStack {
      Text(title)
        .font(Typography.baseTextFonts, bold: true)
        .foregroundStyle(Color.Theme.Foreground.Primary.Primary800)
        .accessibilityAddTraits(.isHeader)

      HStack {
        Spacer()
        Button(action: onDismiss) {
          Image(systemName: "xmark")
            .foregroundStyle(Color.Theme.Foreground.Primary.Primary750)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String.textSelectionCloseLabel))
      }
    }
    .padding(.vertical, 18)
    .padding(.horizontal, 24)
    .overlay(
      Rectangle()
        .frame(height: 1)
        .foregroundStyle(Color.Theme.Stroke.Default.Default250),
      alignment: .bottom
    )
  }
}

#if DEBUG
#Preview {
  TextSelectionView(
    text: "The quick brown fox jumps over the lazy dog.\n\nSecond paragraph for selection.",
    onDismiss: {}
  )
}
#endif
