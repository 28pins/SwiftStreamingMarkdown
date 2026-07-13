//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

#if canImport(UIKit)
import UIKit
/// Cross-platform image type. Resolves to `UIImage` on UIKit platforms and `NSImage` on AppKit platforms.
public typealias MDImage = UIImage
#elseif canImport(AppKit)
import AppKit
/// Cross-platform image type. Resolves to `UIImage` on UIKit platforms and `NSImage` on AppKit platforms.
public typealias MDImage = NSImage
#endif

extension MDImage {
  /// Creates a cross-platform image from an SF Symbol name.
  public convenience init?(sfSymbol name: String) {
    #if canImport(UIKit)
    self.init(systemName: name)
    #elseif canImport(AppKit)
    self.init(systemSymbolName: name, accessibilityDescription: nil)
    #endif
  }

  /// Loads a loose image resource from the app's main bundle by name.
  ///
  /// The name may include a file extension (e.g. `logo.png`); when omitted, the
  /// main bundle is searched for a resource with that base name.
  static func bundledResource(named name: String) -> MDImage? {
    let resourceName = (name as NSString).deletingPathExtension
    let fileExtension = (name as NSString).pathExtension
    guard let url = Bundle.main.url(
      forResource: resourceName,
      withExtension: fileExtension.isEmpty ? nil : fileExtension
    ) else {
      return nil
    }
    #if canImport(UIKit)
    return UIImage(contentsOfFile: url.path)
    #elseif canImport(AppKit)
    return NSImage(contentsOf: url)
    #endif
  }
}
