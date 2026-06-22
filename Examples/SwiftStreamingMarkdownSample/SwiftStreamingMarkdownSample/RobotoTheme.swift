//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import SwiftStreamingMarkdown
import SwiftUI

enum RobotoTheme {

  // MARK: - Colors

  private static func color(_ name: String) -> PlatformColor {
    #if os(macOS)
    NSColor(named: "RobotoTheme/\(name)") ?? .systemPink
    #else
    UIColor(named: "RobotoTheme/\(name)") ?? .systemPink
    #endif
  }

  private static var pageForeground: PlatformColor { color("PageForeground") }
  private static var mutedForeground: PlatformColor { color("MutedForeground") }
  private static var accent: PlatformColor { color("Accent") }
  private static var accentSoft: PlatformColor { color("AccentSoft") }
  private static var boldEmphasis: PlatformColor { color("BoldEmphasis") }
  private static var codeForeground: PlatformColor { color("CodeForeground") }
  private static var codeBackground: PlatformColor { color("CodeBackground") }
  private static var codeUnderline: PlatformColor { color("CodeUnderline") }
  private static var tableHeaderBackground: PlatformColor { color("TableHeaderBackground") }
  private static var tableBorder: PlatformColor { color("TableBorder") }

  static var pageBackground: Color { Color("RobotoTheme/PageBackground") }

  // MARK: - Fonts

  private static func roboto(_ size: CGFloat, weight: String = "Regular") -> PlatformFont {
    #if os(macOS)
    NSFont(name: "Roboto-\(weight)", size: size)
      ?? .systemFont(ofSize: size, weight: weight == "Bold" ? .bold : (weight == "Medium" ? .medium : .regular))
    #else
    UIFont(name: "Roboto-\(weight)", size: size)
      ?? .systemFont(ofSize: size, weight: weight == "Bold" ? .bold : (weight == "Medium" ? .medium : .regular))
    #endif
  }

  private static func robotoItalic(_ size: CGFloat, bold: Bool = false) -> PlatformFont {
    let name = bold ? "Roboto-BoldItalic" : "Roboto-Italic"
    #if os(macOS)
    return NSFont(name: name, size: size)
      ?? NSFont.systemFont(ofSize: size)
    #else
    return UIFont(name: name, size: size)
      ?? .italicSystemFont(ofSize: size)
    #endif
  }

  private static func textFonts(size: CGFloat, lineHeight: CGFloat? = nil, letterSpacing: CGFloat? = nil) -> TextFonts {
    TextFonts(
      normal: roboto(size, weight: "Regular"),
      italic: robotoItalic(size),
      bold: roboto(size, weight: "Bold"),
      boldItalic: robotoItalic(size, bold: true),
      preferredLetterSpacing: letterSpacing,
      preferredLineHeight: lineHeight
    )
  }

  private static func headingFonts(size: CGFloat, letterSpacing: CGFloat) -> TextFonts {
    TextFonts(
      normal: roboto(size, weight: "Medium"),
      italic: robotoItalic(size),
      bold: roboto(size, weight: "Bold"),
      boldItalic: robotoItalic(size, bold: true),
      preferredLetterSpacing: letterSpacing,
      preferredLineHeight: size * 1.2
    )
  }

  // MARK: - Config

  static let renderConfig: MarkdownRenderConfig = MarkdownRenderConfig(
    shouldAnimateText: false,
    blockQuoteStyle: .init(
      textFonts: textFonts(size: 16, lineHeight: 24),
      textColor: mutedForeground
    ),
    headingStyle: .init(
      h1Font: headingFonts(size: 32, letterSpacing: -0.5),
      h2Font: headingFonts(size: 26, letterSpacing: -0.25),
      h3Font: headingFonts(size: 22, letterSpacing: 0),
      h4Font: headingFonts(size: 19, letterSpacing: 0),
      h5Font: headingFonts(size: 17, letterSpacing: 0.5),
      h6Font: headingFonts(size: 15, letterSpacing: 0.75),
      textColor: accent
    ),
    orderedListStyle: .init(
      textFonts: textFonts(size: 16, lineHeight: 24),
      textColor: pageForeground
    ),
    paragraphStyle: .init(
      textFonts: textFonts(size: 16, lineHeight: 24, letterSpacing: 0.15),
      textColor: pageForeground
    ),
    tableStyle: .init(
      textFonts: textFonts(size: 14, lineHeight: 20),
      headerTextColor: accent,
      regularTextColor: pageForeground,
      headerBackgroundColor: tableHeaderBackground,
      borderColor: tableBorder,
      actionButtonColor: accent
    ),
    inlineStyle: .init(
      boldTextColor: boldEmphasis,
      linkTextFont: roboto(16, weight: "Medium"),
      linkTextColor: accent,
      codeTextFont: PlatformFont.monospacedSystemFont(ofSize: 15, weight: .regular),
      codeTextColor: codeForeground,
      codeBackgroundColor: codeBackground,
      codeUnderlineColor: codeUnderline
    ),
    textContextMenu: nil,
    citationConfig: .init(
      isEnabled: true,
      font: roboto(12, weight: "Medium"),
      textColor: pageForeground,
      backgroundColor: accentSoft
    )
  )
}
