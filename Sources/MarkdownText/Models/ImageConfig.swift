//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation

/// Configuration controlling whether and how Markdown images are rendered as
/// block-level content.
///
/// - Important: Image support is **experimental**. The behavior, API, and
///   rendering output may change in future releases.
public struct ImageConfig: Hashable, Sendable {

  /// A category of image source permitted while image rendering is enabled.
  public enum ImageType: Hashable, Sendable {
    /// Remote images loaded over `http`/`https`, restricted to the hosts in
    /// `allowedDomains`.
    ///
    /// An empty list permits any host. Matching is case-insensitive and
    /// includes subdomains, so `example.com` also matches `cdn.example.com`.
    case remote(allowedDomains: [String])
  }

  /// Whether Markdown images are rendered as block-level content.
  public let enabled: Bool

  /// The image sources permitted while `enabled` is `true`. An image whose
  /// source matches none of these types renders a placeholder instead.
  public let allowedImageTypes: [ImageType]

  /// Create an image configuration.
  /// - Parameters:
  ///   - enabled: See `enabled`. Defaults to `false`.
  ///   - allowedImageTypes: See `allowedImageTypes`. Defaults to empty, which
  ///     permits no image sources.
  public init(enabled: Bool = false, allowedImageTypes: [ImageType] = []) {
    self.enabled = enabled
    self.allowedImageTypes = allowedImageTypes
  }

  /// Image support disabled.
  public static let disabled = ImageConfig(enabled: false)

  /// Whether an image loaded from `url` may be rendered under this config.
  ///
  /// Returns `false` when image support is disabled, the URL is missing, or the
  /// URL matches none of the `allowedImageTypes`.
  func allowsImage(from url: URL?) -> Bool {
    guard enabled, let url else { return false }
    return allowedImageTypes.contains { $0.allows(url) }
  }
}

extension ImageConfig.ImageType {

  /// Whether `url` satisfies this image type.
  func allows(_ url: URL) -> Bool {
    switch self {
    case .remote(let allowedDomains):
      guard let scheme = url.scheme?.lowercased(),
        scheme == "http" || scheme == "https",
        let host = url.host?.lowercased() else {
        return false
      }
      guard !allowedDomains.isEmpty else { return true }
      return allowedDomains.contains { domain in
        let domain = domain.lowercased()
        return host == domain || host.hasSuffix("." + domain)
      }
    }
  }
}
