//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation

#if os(macOS)
import AppKit
public typealias PlatformFont = NSFont
public typealias PlatformColor = NSColor
public typealias PlatformImage = NSImage
public typealias PlatformEdgeInsets = NSEdgeInsets

extension NSFont {
  /// Computed line height matching UIFont.lineHeight semantics.
  var lineHeight: CGFloat {
    return ceil(ascender + abs(descender) + leading)
  }
}
#else
import UIKit
public typealias PlatformFont = UIFont
public typealias PlatformColor = UIColor
public typealias PlatformImage = UIImage
public typealias PlatformEdgeInsets = UIEdgeInsets
#endif
