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
    /// A loose image resource resolved from the app's main bundle by name.
    case bundledResource(name: String)
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
  /// The source's URL scheme determines its type:
  /// - `https` → `.remote`, validated against the remote allowlist. Plain
  ///   `http` and all other explicit schemes are rejected.
  /// - `assets` → `.assetCatalog`, with the remainder of the source as the
  ///   asset name (e.g. `assets://Images/logo` → `Images/logo`).
  /// - no scheme (a relative path) → `.bundledResource`, with a leading `./`
  ///   stripped (e.g. `./logo.png` → `logo.png`).
  ///
  /// Returns `nil` when image support is disabled, the source is empty, or the
  /// resolved type is not among the config's `allowedImageTypes`.
  private static func resolveSource(rawSource: String?, imageConfig: ImageConfig) -> Source? {
    guard imageConfig.enabled, let rawSource, !rawSource.isEmpty else { return nil }

    let url = URL.fromMixedEncodingString(rawSource)
    switch url?.scheme?.lowercased() {
    case "https":
      guard let url, imageConfig.allowsImage(from: url) else { return nil }
      return .remote(url)
    case "assets":
      guard imageConfig.allowsAssetCatalog,
        let name = assetCatalogName(scheme: "assets", rawSource: rawSource) else {
        return nil
      }
      return .assetCatalog(name: name)
    case .some:
      // An explicit but unsupported scheme (e.g. `file`, `data`).
      return nil
    case .none:
      guard imageConfig.allowsBundledResource else { return nil }
      return .bundledResource(name: bundledResourceName(rawSource: rawSource))
    }
  }

  /// Extracts the asset name from an `assets`-scheme source by dropping the
  /// scheme prefix, e.g. `assets://Images/logo` → `Images/logo`.
  private static func assetCatalogName(scheme: String, rawSource: String) -> String? {
    let prefix = scheme + "://"
    guard rawSource.count > prefix.count else { return nil }
    let name = String(rawSource.dropFirst(prefix.count))
    return name.isEmpty ? nil : name
  }

  /// Normalizes a scheme-less relative path into a bundle resource name by
  /// stripping a leading `./`, e.g. `./logo.png` → `logo.png`.
  private static func bundledResourceName(rawSource: String) -> String {
    rawSource.hasPrefix("./") ? String(rawSource.dropFirst(2)) : rawSource
  }
}
