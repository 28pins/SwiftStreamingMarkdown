//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif
import UniformTypeIdentifiers

final class InlineCitationAttachment: NSTextAttachment {
  /// The decoded citation data - available immediately without JSON parsing
  private(set) var citationData: InlineAttachmentData?

  /// Styling resolved from the active `CitationConfig`. Exposed so the live
  /// label provider can mirror the same look as the precomputed preview image.
  let font: PlatformFont
  let textColor: PlatformColor
  let backgroundColor: PlatformColor

  // MARK: - Interface style tracking

  enum InterfaceStyle {
    case light, dark
  }

  private static var currentInterfaceStyle: InterfaceStyle = .dark
  private static let styleLock = NSLock()

  #if os(iOS)
  static func updateInterfaceStyle(_ style: UIUserInterfaceStyle) {
    styleLock.lock()
    defer { styleLock.unlock() }
    currentInterfaceStyle = style == .dark ? .dark : .light
  }
  #endif

  static func updateInterfaceStyle(_ style: InterfaceStyle) {
    styleLock.lock()
    defer { styleLock.unlock() }
    currentInterfaceStyle = style
  }

  private static var latestStyle: InterfaceStyle {
    styleLock.lock()
    defer { styleLock.unlock() }
    return currentInterfaceStyle
  }

  // MARK: - Precomputed preview images

  #if os(macOS)
  private var lightPreviewImage: NSImage?
  private var darkPreviewImage: NSImage?
  private var assignedImage: NSImage?

  static let textInsets = NSEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
  static let cornerRadius: CGFloat = 6

  override var image: NSImage? {
    get {
      if let assignedImage { return assignedImage }
      return Self.latestStyle == .dark ? darkPreviewImage : lightPreviewImage
    }
    set {
      assignedImage = newValue
    }
  }
  #else
  private var lightPreviewImage: UIImage?
  private var darkPreviewImage: UIImage?
  private var assignedImage: UIImage?

  static let textInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
  static let cornerRadius: CGFloat = 6

  override var image: UIImage? {
    get {
      if let assignedImage { return assignedImage }
      return Self.latestStyle == .dark ? darkPreviewImage : lightPreviewImage
    }
    set {
      assignedImage = newValue
    }
  }
  #endif

  /// Called during markdown parsing (background queue). Rasterizes both
  /// light/dark previews here so the getter never does work on the main thread.
  init(payload: Data, citationConfig: MarkdownRenderConfig.CitationConfig) {
    let decoded = try? JSONDecoder().decode(InlineAttachmentData.self, from: payload)
    let citationData = (decoded?.type == .citation) ? decoded : nil
    self.citationData = citationData

    self.font = citationConfig.font
    self.textColor = citationConfig.textColor
    self.backgroundColor = citationConfig.backgroundColor

    if let title = citationData?.title {
      self.lightPreviewImage = Self.renderCitationImage(
        title: title,
        font: self.font,
        textColor: self.textColor,
        backgroundColor: self.backgroundColor,
        isDark: false
      )
      self.darkPreviewImage = Self.renderCitationImage(
        title: title,
        font: self.font,
        textColor: self.textColor,
        backgroundColor: self.backgroundColor,
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

  #if os(macOS)
  private static func renderCitationImage(
    title: String,
    font: NSFont,
    textColor: NSColor,
    backgroundColor: NSColor,
    isDark: Bool
  ) -> NSImage {
    let textInsets = Self.textInsets
    let cornerRadius = Self.cornerRadius

    let appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)!
    var resolvedTextColor = textColor
    var resolvedBackgroundColor = backgroundColor
    appearance.performAsCurrentDrawingAppearance {
      resolvedTextColor = textColor
      resolvedBackgroundColor = backgroundColor
    }

    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: resolvedTextColor
    ]
    let textSize = (title as NSString).size(withAttributes: attributes)
    let totalSize = CGSize(
      width: ceil(textSize.width) + textInsets.left + textInsets.right,
      height: ceil(textSize.height) + textInsets.top + textInsets.bottom
    )

    let image = NSImage(size: totalSize, flipped: true) { rect in
      let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
      resolvedBackgroundColor.setFill()
      path.fill()

      let textRect = CGRect(
        x: textInsets.left,
        y: textInsets.top,
        width: ceil(textSize.width),
        height: ceil(textSize.height)
      )
      (title as NSString).draw(in: textRect, withAttributes: attributes)
      return true
    }
    return image
  }
  #else
  private static func renderCitationImage(
    title: String,
    font: UIFont,
    textColor: UIColor,
    backgroundColor: UIColor,
    isDark: Bool
  ) -> UIImage {
    let textInsets = Self.textInsets
    let cornerRadius = Self.cornerRadius
    let traitCollection = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
    let resolvedTextColor = textColor.resolvedColor(with: traitCollection)
    let resolvedBackgroundColor = backgroundColor.resolvedColor(with: traitCollection)

    let attributes: [NSAttributedString.Key: Any] = [
      .font: font,
      .foregroundColor: resolvedTextColor
    ]
    let textSize = (title as NSString).size(withAttributes: attributes)
    let totalSize = CGSize(
      width: ceil(textSize.width) + textInsets.left + textInsets.right,
      height: ceil(textSize.height) + textInsets.top + textInsets.bottom
    )

    let renderer = UIGraphicsImageRenderer(size: totalSize)
    return renderer.image { _ in
      let rect = CGRect(origin: .zero, size: totalSize)
      let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
      resolvedBackgroundColor.setFill()
      path.fill()

      let textRect = CGRect(
        x: textInsets.left,
        y: textInsets.top,
        width: ceil(textSize.width),
        height: ceil(textSize.height)
      )
      (title as NSString).draw(in: textRect, withAttributes: attributes)
    }
  }
  #endif
}
