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
///   `MarkdownRenderConfig.imageSupport`.
struct ImageData: Equatable, Sendable {

  /// The resolved image source URL, or `nil` when the source is missing or
  /// cannot be parsed.
  let url: URL?

  /// The image's alternate text, used as the accessibility label.
  let alt: String

  init(url: URL?, alt: String) {
    self.url = url
    self.alt = alt
  }

  init(image: Markdown.Image) {
    self.url = image.source.flatMap { URL.fromMixedEncodingString($0) }
    self.alt = image.plainText
  }
}
