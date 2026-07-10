//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import SwiftUI

/// Renders a block-level Markdown image, loading it asynchronously from its URL.
///
/// - Important: Image support is **experimental**. See
///   `MarkdownRenderConfig.imageSupport`.
struct BlockImageView: View {

  let data: ImageData

  var body: some View {
    AsyncImage(url: data.url) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .scaledToFit()
      case .failure:
        placeholder(systemImage: "photo")
      case .empty:
        placeholder(systemImage: "photo")
      @unknown default:
        placeholder(systemImage: "photo")
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityLabel(data.alt.isEmpty ? Text("Image") : Text(data.alt))
    .transition(.opacity)
  }

  private func placeholder(systemImage: String) -> some View {
    Image(systemName: systemImage)
      .imageScale(.large)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
  }
}
