//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation

extension ImageConfig {

  /// Resolves a Markdown image source string into a permitted `ImageData.Source`.
  ///
  /// The source's URL scheme determines its type:
  /// - `https` → `.remote`, validated against the remote allowlist. Plain
  ///   `http` and all other explicit schemes are rejected.
  /// - `assets` → `.assetCatalog`, with the asset name taken from the URL's
  ///   host and path (e.g. `assets://Images/logo` → `Images/logo`).
  /// - no scheme (a relative path) → `.bundledResource`, split into its base
  ///   file name and extension (e.g. `./logo.png` → `logo` + `png`). Nested
  ///   paths and sources without an extension are rejected.
  ///
  /// Returns `nil` when image support is disabled, the source is empty, or the
  /// resolved type is not among `allowedImageTypes`.
  func resolvedSource(for rawSource: String?) -> ImageData.Source? {
    guard enabled, let rawSource, !rawSource.isEmpty,
      let url = URL.fromMixedEncodingString(rawSource) else {
      return nil
    }

    switch url.scheme?.lowercased() {
    case "https":
      guard allowsImage(from: url) else { return nil }
      return .remote(url)
    case "assets":
      guard allowsAssetCatalog, let name = Self.assetCatalogName(from: url) else { return nil }
      return .assetCatalog(name: name)
    case .some:
      // An explicit but unsupported scheme (e.g. `file`, `data`).
      return nil
    case .none:
      guard allowsBundledResource,
        let resource = Self.bundledResource(from: rawSource) else {
        return nil
      }
      return .bundledResource(fileName: resource.fileName, ext: resource.ext)
    }
  }

  /// Builds the asset name for an `assets`-scheme source from the URL's host and
  /// path, e.g. `assets://Images/logo` → `Images/logo`.
  private static func assetCatalogName(from url: URL) -> String? {
    let name = (url.host(percentEncoded: false) ?? "") + url.path(percentEncoded: false)
    return name.isEmpty ? nil : name
  }

  /// Splits a scheme-less relative path into a bundle resource's base file name
  /// and extension, e.g. `./logo.png` → (`logo`, `png`). Returns `nil` for
  /// nested paths or sources without a file extension.
  private static func bundledResource(from rawSource: String) -> (fileName: String, ext: String)? {
    let path = rawSource.hasPrefix("./") ? String(rawSource.dropFirst(2)) : rawSource
    // Only a bare file name is supported; nested paths are invalid.
    guard !path.isEmpty, !path.contains("/") else { return nil }

    let fileName = (path as NSString).deletingPathExtension
    let ext = (path as NSString).pathExtension
    guard !fileName.isEmpty, !ext.isEmpty else { return nil }
    return (fileName, ext)
  }
}
