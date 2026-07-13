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
    /// A remote image loaded asynchronously over `https`.
    case remote(URL)
    /// A bundled image resolved from the app's asset catalog by name.
    case assetCatalog(name: String)
    /// A loose image resource resolved from the app's main bundle by its base
    /// file name and extension (e.g. `logo.png` → `fileName: "logo"`,
    /// `ext: "png"`).
    case bundledResource(fileName: String, ext: String)
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
    self.source = imageConfig.resolvedSource(for: image.source)
  }
}
