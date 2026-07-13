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

  /// The resolved image source URL, or `nil` when the source is missing or
  /// cannot be parsed.
  let url: URL?

  /// The image's alternate text, used as the accessibility label.
  let alt: String

  /// Whether `url` is permitted by the active `ImageConfig`. Precomputed during
  /// pre-rendering so the view layer does not evaluate eligibility in its body.
  let isDomainAllowed: Bool

  init(url: URL?, alt: String, isDomainAllowed: Bool) {
    self.url = url
    self.alt = alt
    self.isDomainAllowed = isDomainAllowed
  }

  init(image: Markdown.Image, imageConfig: ImageConfig) {
    let url = image.source.flatMap { URL.fromMixedEncodingString($0) }
    self.url = url
    self.alt = image.plainText
    self.isDomainAllowed = imageConfig.allowsImage(from: url)
  }
}
