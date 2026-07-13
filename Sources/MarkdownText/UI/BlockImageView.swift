//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import Shimmer
import SwiftUI

/// Renders a block-level Markdown image, loaded asynchronously from a remote
/// URL, resolved from the app's asset catalog, or loaded from a bundled
/// resource file.
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
    switch data.source {
    case .remote(let url):
      remoteImage(url: url)
    case .assetCatalog(let name):
      Image(name)
        .resizable()
        .scaledToFit()
    case .bundledResource(let name):
      BundledResourceImage(name: name)
    case nil:
      ImagePlaceholder.failure
    }
  }

  @ViewBuilder
  private func remoteImage(url: URL) -> some View {
    AsyncImage(url: url) { phase in
      switch phase {
      case .success(let image):
        image
          .resizable()
          .scaledToFit()
      case .failure:
        ImagePlaceholder.failure
      case .empty:
        ImagePlaceholder.loading
      @unknown default:
        ImagePlaceholder.failure
      }
    }
  }
}

/// Loads and renders a loose image resource from the app's main bundle.
private struct BundledResourceImage: View {

  let name: String

  @State private var image: MDImage?
  @State private var didLoad = false

  var body: some View {
    Group {
      if let image {
        Image(mdImage: image)
          .resizable()
          .scaledToFit()
      } else if didLoad {
        ImagePlaceholder.failure
      } else {
        ImagePlaceholder.loading
      }
    }
    .task {
      image = MDImage.bundledResource(named: name)
      didLoad = true
    }
  }
}

/// Shared placeholders for the loading and failed states of a block image.
private enum ImagePlaceholder {

  static var loading: some View {
    RoundedRectangle(cornerRadius: 8)
      .fill(.quaternary)
      .frame(maxWidth: .infinity)
      .frame(height: 200)
      .shimmering()
      .accessibilityHidden(true)
  }

  static var failure: some View {
    Image(systemName: "photo.badge.exclamationmark")
      .imageScale(.large)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .center)
  }
}
