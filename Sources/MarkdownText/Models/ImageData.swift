//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import Markdown

/// The payload for an image-only block, promoted from a Markdown `Image` node
/// during pre-rendering.
///
/// - Important: Image support is **experimental**. See
///   `MarkdownRenderConfig.imageConfig`.
struct ImageData: Equatable, Sendable {

  /// A resolved image source that the active `ImageConfig` permits.
  enum Source: Equatable, Sendable {
    /// A remote image loaded asynchronously over the network.
    case remote(URL)
    /// A bundled image resolved from the app's asset catalog by name.
    case assetCatalog(name: String)
  }

  /// The permitted image source, or `nil` when the source is missing,
  /// unparseable, or not allowed by the config — in which case the view layer
  /// renders a placeholder. Precomputed during pre-rendering so the view does
  /// not evaluate eligibility in its body.
  let source: Source?

  /// The image's alternate text, used as the accessibility label.
  let alt: String

  init(source: Source?, alt: String) {
    self.source = source
    self.alt = alt
  }

  init(image: Markdown.Image, imageConfig: ImageConfig) {
    self.alt = image.plainText
    self.source = Self.resolveSource(rawSource: image.source, imageConfig: imageConfig)
  }

  /// Resolves a Markdown image source string into a permitted `Source`.
  ///
  /// A source with an explicit URL scheme is treated as a remote image and
  /// validated against the remote allowlist. A scheme-less source is treated as
  /// a relative path and resolved from the asset catalog when permitted.
  private static func resolveSource(rawSource: String?, imageConfig: ImageConfig) -> Source? {
    guard imageConfig.enabled, let rawSource, !rawSource.isEmpty else { return nil }

    let url = URL.fromMixedEncodingString(rawSource)
    if let url, url.scheme != nil {
      return imageConfig.allowsImage(from: url) ? .remote(url) : nil
    }

    return imageConfig.allowsAssetCatalog ? .assetCatalog(name: rawSource) : nil
  }
}
