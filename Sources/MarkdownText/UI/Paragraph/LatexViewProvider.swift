//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import iosMath
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - LatexAttachmentData Color Resolution

extension LatexAttachmentData {
  var resolvedTextColor: MDColor {
    let fallback = MDColor(Color.Theme.Foreground.Primary.Primary750)
    #if canImport(UIKit)
    guard let lightColor = UIColor(hex: lightTextColor),
          let darkColor = UIColor(hex: darkTextColor) else {
      return fallback
    }
    return UIColor { trait in
      trait.userInterfaceStyle == .dark ? darkColor : lightColor
    }
    #elseif canImport(AppKit)
    guard let lightColor = NSColor(hex: lightTextColor),
          let darkColor = NSColor(hex: darkTextColor) else {
      return fallback
    }
    return NSColor(name: nil) { appearance in
      let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
      return isDark ? darkColor : lightColor
    }
    #endif
  }
}

// MARK: - Latex View Provider

final class LatexViewProvider: NSTextAttachmentViewProvider {
  private let latex: String
  private let fontSize: CGFloat
  private let textColor: MDColor
  private static let jsonDecoder = JSONDecoder()

  #if canImport(UIKit)
  required override init(textAttachment attachment: NSTextAttachment,
                         parentView: UIView?,
                         textLayoutManager: NSTextLayoutManager?,
                         location: any NSTextLocation) {
    (latex, fontSize, textColor) = Self.decode(attachment: attachment)
    super.init(textAttachment: attachment, parentView: parentView,
               textLayoutManager: textLayoutManager, location: location)
    tracksTextAttachmentViewBounds = true
  }
  #elseif canImport(AppKit)
  required override init(textAttachment attachment: NSTextAttachment,
                         parentView: NSView?,
                         textLayoutManager: NSTextLayoutManager?,
                         location: any NSTextLocation) {
    (latex, fontSize, textColor) = Self.decode(attachment: attachment)
    super.init(textAttachment: attachment, parentView: parentView,
               textLayoutManager: textLayoutManager, location: location)
    tracksTextAttachmentViewBounds = true
  }
  #endif

  // swiftlint:disable:next large_tuple
  private static func decode(attachment: NSTextAttachment) -> (String, CGFloat, MDColor) {
    var latex = ""
    var fontSize = Typography.base.mdFont.pointSize
    var textColor: MDColor = MDColor(Color.Theme.Foreground.Primary.Primary750)
    if let data = attachment.contents,
       let attachmentData = try? jsonDecoder.decode(LatexAttachmentData.self, from: data) {
      latex = attachmentData.latex
      fontSize = attachmentData.fontSize
      textColor = attachmentData.resolvedTextColor
    }
    return (latex, fontSize, textColor)
  }

  override func loadView() {
    let label = MTMathUILabel()
    label.latex = latex
    label.textColor = textColor
    label.displayErrorInline = false
    label.fontSize = fontSize
    label.setContentHuggingPriority(.defaultHigh, for: .vertical)
    self.view = label
  }

  override func attachmentBounds(for attributes: [NSAttributedString.Key: Any],
                                 location: any NSTextLocation,
                                 textContainer: NSTextContainer?,
                                 proposedLineFragment: CGRect,
                                 position: CGPoint) -> CGRect {
    guard let mathLabel = view as? MTMathUILabel else {
      return .zero
    }
    #if canImport(UIKit)
    mathLabel.sizeToFit()
    let size = mathLabel.bounds.size
    #elseif canImport(AppKit)
    let size = mathLabel.intrinsicContentSize
    #endif
    let height = size.height.rounded(.up) + 1.0
    let font = attributes[.font] as? MDFont ?? MDFont.systemFont(ofSize: fontSize)
    let yOffset = (font.xHeight - height) / 2.0
    return CGRect(x: 0, y: yOffset, width: size.width.rounded(.up), height: height)
  }
}
