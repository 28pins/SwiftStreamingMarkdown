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
  /// As a nonisolated `async` method, this runs off the main actor, so the file
  /// read does not block rendering. Returns `nil` when the resource is missing
  /// or cannot be decoded.
  func bundledResourceImage(withExtension ext: String) async -> MDImage? {
    guard let data = await bundledResourceData(withExtension: ext) else {
      return nil
    }
    return MDImage(data: data)
  }

  /// Reads the raw bytes of a loose image resource from the app's main bundle,
  /// where `self` is the resource's base file name and `ext` its extension.
  ///
  /// As a nonisolated `async` method, this runs off the main actor, so the file
  /// read does not block rendering. Returns `nil` when the resource is missing
  /// or unreadable.
  func bundledResourceData(withExtension ext: String) async -> Data? {
    guard let url = Bundle.main.url(forResource: self, withExtension: ext) else {
      return nil
    }
    return try? Data(contentsOf: url)
  }
}
