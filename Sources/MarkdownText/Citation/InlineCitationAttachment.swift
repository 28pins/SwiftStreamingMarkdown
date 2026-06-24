//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
import UniformTypeIdentifiers

final class InlineCitationAttachment: NSTextAttachment {
  /// The decoded citation data - available immediately without JSON parsing
  private(set) var citationData: InlineAttachmentData?

  /// Styling resolved from the active `CitationConfig`. Exposed so the live
  /// label provider can mirror the same look as the precomputed preview image.
  let font: MDFont
  let textColor: MDColor
  let backgroundColor: MDColor

  // MARK: - Interface style tracking

  #if canImport(UIKit)
  private static var currentInterfaceStyle: UIUserInterfaceStyle = .dark
  #elseif canImport(AppKit)
  private static var currentAppearanceIsDark: Bool = true
  #endif
  private static let styleLock = NSLock()

  #if canImport(UIKit)
  static func updateInterfaceStyle(_ style: UIUserInterfaceStyle) {
    styleLock.lock()
    defer { styleLock.unlock() }
    currentInterfaceStyle = style
  }
  #elseif canImport(AppKit)
  static func updateAppearanceIsDark(_ isDark: Bool) {
    styleLock.lock()
    defer { styleLock.unlock() }
    currentAppearanceIsDark = isDark
  }
  #endif

  private static var isDarkMode: Bool {
    styleLock.lock()
    defer { styleLock.unlock() }
    #if canImport(UIKit)
    return currentInterfaceStyle == .dark
    #elseif canImport(AppKit)
    return currentAppearanceIsDark
    #endif
  }

  // MARK: - Precomputed preview images

  private var lightPreviewImage: MDImage?
  private var darkPreviewImage: MDImage?
  private var assignedImage: MDImage?

  // MARK: - Shared Layout

  static let textInsetTop: CGFloat = 2
  static let textInsetLeft: CGFloat = 4
  static let textInsetBottom: CGFloat = 2
  static let textInsetRight: CGFloat = 4
  static let cornerRadius: CGFloat = 6

  #if canImport(UIKit)
  static let textInsets = UIEdgeInsets(top: textInsetTop, left: textInsetLeft, bottom: textInsetBottom, right: textInsetRight)
  #elseif canImport(AppKit)
  static let textInsets = NSEdgeInsets(top: textInsetTop, left: textInsetLeft, bottom: textInsetBottom, right: textInsetRight)
  #endif

  #if canImport(UIKit)
  override var image: UIImage? {
    get {
      if let assignedImage { return assignedImage }
      return Self.isDarkMode ? darkPreviewImage : lightPreviewImage
    }
    set { assignedImage = newValue }
  }
  #elseif canImport(AppKit)
  override var image: NSImage? {
    get {
      if let assignedImage { return assignedImage }
      return Self.isDarkMode ? darkPreviewImage : lightPreviewImage
    }
    set { assignedImage = newValue }
  }
  #endif

  /// Called during markdown parsing (background queue). Rasterizes both
  /// light/dark previews here so the getter never does work on the main thread.
  init(payload: Data, citationConfig: MarkdownRenderConfig.CitationConfig) {
    let decoded = try? JSONDecoder().decode(InlineAttachmentData.self, from: payload)
    let citationData = (decoded?.type == .citation) ? decoded : nil
    self.citationData = citationData

    self.font = citationConfig.font
    self.textColor = MDColor(citationConfig.textColor)
    self.backgroundColor = MDColor(citationConfig.backgroundColor)

    if let title = citationData?.title {
      self.lightPreviewImage = Self.renderCitationImage(
        title: title, font: self.font,
        textColor: self.textColor, backgroundColor: self.backgroundColor,
        isDark: false
      )
      self.darkPreviewImage = Self.renderCitationImage(
        title: title, font: self.font,
        textColor: self.textColor, backgroundColor: self.backgroundColor,
        isDark: true
      )
    } else {
      self.lightPreviewImage = nil
      self.darkPreviewImage = nil
    }

    super.init(data: payload, ofType: UTType.url.identifier)
  }

  /// Create citation attachment directly from data struct
  convenience init?(citationData: InlineAttachmentData, citationConfig: MarkdownRenderConfig.CitationConfig) {
    guard citationData.type == .citation,
          let payload = try? JSONEncoder().encode(citationData) else {
      return nil
    }
    self.init(payload: payload, citationConfig: citationConfig)
  }

  required init?(coder: NSCoder) {
    return nil
  }

  // MARK: - Preview Image Rendering

  #if canImport(UIKit)
  private static func renderCitationImage(
    title: String, font: MDFont,
    textColor: MDColor, backgroundColor: MDColor,
    isDark: Bool
  ) -> UIImage {
    let traitCollection = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
    let resolvedTextColor = textColor.resolvedColor(with: traitCollection)
    let resolvedBackgroundColor = backgroundColor.resolvedColor(with: traitCollection)

    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: resolvedTextColor]
    let textSize = (title as NSString).size(withAttributes: attributes)
    let totalSize = CGSize(
      width: ceil(textSize.width) + textInsetLeft + textInsetRight,
      height: ceil(textSize.height) + textInsetTop + textInsetBottom
    )

    let renderer = UIGraphicsImageRenderer(size: totalSize)
    return renderer.image { _ in
      let rect = CGRect(origin: .zero, size: totalSize)
      let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
      resolvedBackgroundColor.setFill()
      path.fill()

      let textRect = CGRect(x: textInsetLeft, y: textInsetTop,
                            width: ceil(textSize.width), height: ceil(textSize.height))
      (title as NSString).draw(in: textRect, withAttributes: attributes)
    }
  }
  #elseif canImport(AppKit)
  private static func renderCitationImage(
    title: String, font: MDFont,
    textColor: MDColor, backgroundColor: MDColor,
    isDark: Bool
  ) -> NSImage {
    let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    var resolvedTextColor = textColor
    var resolvedBackgroundColor = backgroundColor
    appearance?.performAsCurrentDrawingAppearance {
      resolvedTextColor = textColor.usingColorSpace(.sRGB) ?? textColor
      resolvedBackgroundColor = backgroundColor.usingColorSpace(.sRGB) ?? backgroundColor
    }

    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: resolvedTextColor]
    let textSize = (title as NSString).size(withAttributes: attributes)
    let totalSize = CGSize(
      width: ceil(textSize.width) + textInsetLeft + textInsetRight,
      height: ceil(textSize.height) + textInsetTop + textInsetBottom
    )

    let image = NSImage(size: totalSize, flipped: false) { rect in
      let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
      resolvedBackgroundColor.setFill()
      path.fill()

      let textRect = CGRect(x: Self.textInsetLeft, y: Self.textInsetBottom,
                            width: ceil(textSize.width), height: ceil(textSize.height))
      (title as NSString).draw(in: textRect, withAttributes: attributes)
      return true
    }
    return image
  }
  #endif
}
