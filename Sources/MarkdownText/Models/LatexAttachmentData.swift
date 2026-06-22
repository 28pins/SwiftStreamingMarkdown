//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import SwiftUI

struct LatexAttachmentData: Codable {
  let latex: String
  let fontSize: CGFloat
  let lightTextColor: String
  let darkTextColor: String
}

extension LatexAttachmentData {
  var resolvedTextColor: PlatformColor {
    let fallback = PlatformColor(Color.Theme.Foreground.Primary.Primary750)
    guard let lightColor = PlatformColor(hex: lightTextColor),
          let darkColor = PlatformColor(hex: darkTextColor) else {
      return fallback
    }
    #if os(macOS)
    return NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return isDark ? darkColor : lightColor
    }
    #else
    return UIColor { trait in
      trait.userInterfaceStyle == .dark ? darkColor : lightColor
    }
    #endif
  }
}
