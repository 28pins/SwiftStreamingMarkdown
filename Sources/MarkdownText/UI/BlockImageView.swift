//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import Shimmer
import SwiftUI

/// Renders a block-level Markdown image, loading it asynchronously from its URL.
///
/// - Important: Image support is **experimental**. See
///   `MarkdownRenderConfig.imageConfig`.
struct BlockImageView: View {

  let data: ImageData

  var body: some View {
    imageContent
      .frame(maxWidth: .infinity, alignment: .center)
      .accessibilityLabel(data.alt.isEmpty ? Text(String.imageLabel) : Text(data.alt))
  }

  @ViewBuilder
  private var imageContent: some View {
    if data.isDomainAllowed {
      AsyncImage(url: data.url) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .scaledToFit()
        case .failure:
          placeholder(systemImage: "photo.badge.exclamationmark")
        case .empty:
          loadingPlaceholder
        @unknown default:
          placeholder(systemImage: "photo.badge.exclamationmark")
        }
      }
    } else {
      placeholder(systemImage: "photo.badge.exclamationmark")
    }
  }

  private var loadingPlaceholder: some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(.quaternary)
      .frame(maxWidth: .infinity)
      .frame(height: 200)
      .shimmering()
      .accessibilityHidden(true)
  }

  private func placeholder(systemImage: String) -> some View {
    Image(systemName: systemImage)
      .imageScale(.large)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
  }
}
