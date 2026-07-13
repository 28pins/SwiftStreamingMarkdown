//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation

extension String {

  /// Loads a loose image resource from the app's main bundle, where `self` is
  /// the resource's base file name and `ext` its extension (e.g.
  /// `"logo".bundledResourceImage(withExtension: "png")`).
  ///
  /// The file is read off the main actor to avoid blocking rendering; the
  /// resulting `MDImage` is decoded on the caller's actor since `UIImage` and
  /// `NSImage` are not `Sendable`. Returns `nil` when the resource is missing
  /// or cannot be decoded.
  func bundledResourceImage(withExtension ext: String) async -> MDImage? {
    let fileName = self
    let data = await Task.detached(priority: .utility) { () -> Data? in
      guard let url = Bundle.main.url(forResource: fileName, withExtension: ext) else {
        return nil
      }
      return try? Data(contentsOf: url)
    }.value

    guard let data else { return nil }
    return MDImage(data: data)
  }
}
