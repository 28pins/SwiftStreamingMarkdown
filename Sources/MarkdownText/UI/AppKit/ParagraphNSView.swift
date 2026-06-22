//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

#if os(macOS)
import AppKit
import iosMath
import QuartzCore
import SwiftUI
import UniformTypeIdentifiers

struct FadeAnimationData {
  let id: UUID = UUID()
  let startTime: CFTimeInterval
  let duration: CFTimeInterval
  let range: NSRange
}

private struct CachedParagraphNSViewSize {
  let size: CGSize
  let targetWidth: CGFloat
}

class ParagraphNSView: NSTextView {
  private static let jsonEncoder = JSONEncoder()
  static let animationDuration: CFTimeInterval = 0.5

  private(set) var paragraphContents: NSMutableAttributedString = NSMutableAttributedString()
  private(set) var lineSpacing: CGFloat?
  private var activeAnimations: [FadeAnimationData] = []
  private var fadeAnimationDisplayLink: CADisplayLink?
  private var cachedSize: CachedParagraphNSViewSize?

  var textContextMenu: TextContextMenu?
  var markdownController: MarkdownController?

  var onUrlTap: (URL) -> Void = { NSWorkspace.shared.open($0) }

  override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
    super.init(frame: frameRect, textContainer: container)
    setupView()
  }

  convenience init() {
    let textStorage = NSTextStorage()
    let layoutManager = NSLayoutManager()
    textStorage.addLayoutManager(layoutManager)
    let textContainer = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
    textContainer.widthTracksTextView = true
    textContainer.heightTracksTextView = false
    layoutManager.addTextContainer(textContainer)
    self.init(frame: .zero, textContainer: textContainer)
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
    setupView()
  }

  deinit {
    tearDownDisplayLink()
    activeAnimations.removeAll()
  }

  // MARK: - Appearance

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    InlineCitationAttachment.updateInterfaceStyle(isDark ? .dark : .light)
  }

  // MARK: - Intrinsic Content Size

  override var intrinsicContentSize: NSSize {
    if let cachedSize {
      return cachedSize.size
    }
    var targetWidth = bounds.width
    if targetWidth <= 0 || targetWidth.isInfinite {
      targetWidth = NSScreen.main?.frame.width ?? 800
    }

    guard let textContainer, let layoutManager = textContainer.layoutManager else {
      return .zero
    }
    textContainer.containerSize = NSSize(width: targetWidth, height: CGFloat.greatestFiniteMagnitude)
    layoutManager.ensureLayout(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)
    let roundedUpSize = CGSize(width: usedRect.width.rounded(.up), height: usedRect.height.rounded(.up))
    cachedSize = CachedParagraphNSViewSize(size: roundedUpSize, targetWidth: targetWidth)
    return roundedUpSize
  }

  override func layout() {
    super.layout()
    if bounds.width != cachedSize?.targetWidth {
      invalidateCachedSize()
    }
    invalidateIntrinsicContentSize()
  }

  // MARK: - Content Update

  func setParagraphContents(_ newContents: NSMutableAttributedString, lineSpacing: CGFloat? = nil, animatedByWord: Bool) {
    let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    InlineCitationAttachment.updateInterfaceStyle(isDark ? .dark : .light)

    guard paragraphContents != newContents || self.lineSpacing != lineSpacing else {
      return
    }
    self.paragraphContents = newContents
    self.lineSpacing = lineSpacing

    let oldLength = textStorage?.length ?? 0
    let finalString: NSMutableAttributedString
    if lineSpacing != nil {
      finalString = applyLineSpacing(to: newContents, lineSpacing: lineSpacing)
    } else {
      finalString = newContents
    }

    tearDownDisplayLink()
    invalidateCachedSize()
    textStorage?.setAttributedString(finalString)

    invalidateIntrinsicContentSize()

    let newContentLength = (textStorage?.length ?? 0) - oldLength

    if animatedByWord, newContentLength > 0 {
      let newContentRange = NSRange(location: oldLength, length: newContentLength)
      let wordRanges = finalString.splitIntoWords(withIn: newContentRange)
      let wordCount = wordRanges.count
      let delayBetweenWords: Double = 0.1 / Double(max(wordCount, 1))
      let baseStartTime = CACurrentMediaTime()
      for (index, wordRange) in wordRanges.enumerated() {
        let animationData = FadeAnimationData(
          startTime: baseStartTime + Double(index) * delayBetweenWords,
          duration: Self.animationDuration,
          range: wordRange
        )
        activeAnimations.append(animationData)
      }

      updateTextViewWithCurrentAnimations()

      if fadeAnimationDisplayLink == nil {
        setUpDisplayLink()
      }
    } else {
      activeAnimations.removeAll()
    }
  }

  // MARK: - Line Spacing

  private func applyLineSpacing(to attributedString: NSMutableAttributedString, lineSpacing: CGFloat?) -> NSMutableAttributedString {
    let result = NSMutableAttributedString(attributedString: attributedString)
    if let lineSpacing {
      let paragraphStyle = NSMutableParagraphStyle()
      paragraphStyle.lineSpacing = lineSpacing
      paragraphStyle.alignment = .left
      result.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: result.length))
    }
    return result
  }

  // MARK: - View Setup

  private func setupView() {
    if NSTextAttachment.textAttachmentViewProviderClass(forFileType: UTType.data.identifier) == nil {
      NSTextAttachment.registerViewProviderClass(LatexViewProviderMac.self, forFileType: UTType.data.identifier)
    }
    if NSTextAttachment.textAttachmentViewProviderClass(forFileType: UTType.url.identifier) == nil {
      NSTextAttachment.registerViewProviderClass(InlineCitationViewProviderMac.self, forFileType: UTType.url.identifier)
    }

    isEditable = false
    isSelectable = true
    drawsBackground = false
    textContainer?.lineFragmentPadding = 0
    textContainer?.widthTracksTextView = true
    textContainer?.heightTracksTextView = false
    textContainer?.maximumNumberOfLines = 0
    textContainer?.lineBreakMode = .byWordWrapping

    isVerticallyResizable = true
    isHorizontallyResizable = false

    linkTextAttributes = [:]

    setContentHuggingPriority(.defaultHigh, for: .vertical)
    setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
    setContentHuggingPriority(.defaultLow, for: .horizontal)
    setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
  }

  // MARK: - Fade Animation

  private func easeOut(_ t: CGFloat) -> CGFloat {
    let c2: CGFloat = 0.1
    let c4: CGFloat = 1.0

    let t2 = t * t
    let t3 = t2 * t
    let mt = 1 - t
    let mt2 = mt * mt

    return 3 * mt2 * t * c2 + 3 * mt * t2 * c4 + t3
  }

  @objc private func updateFadeAnimation() {
    let currentTime = CACurrentMediaTime()
    var completedAnimations: [UUID] = []

    updateTextViewWithCurrentAnimations()

    for animation in activeAnimations {
      let elapsed = currentTime - animation.startTime
      let progress = elapsed / animation.duration
      if progress >= 1.0 {
        completedAnimations.append(animation.id)
      }
    }
    activeAnimations.removeAll { completedAnimations.contains($0.id) }

    if activeAnimations.isEmpty {
      tearDownDisplayLink()
    }
  }

  private func updateTextViewWithCurrentAnimations() {
    guard let textStorage else { return }
    let currentTime = CACurrentMediaTime()

    textStorage.beginEditing()
    defer { textStorage.endEditing() }

    for animation in activeAnimations {
      guard animation.range.location + animation.range.length <= textStorage.length else {
        continue
      }
      let elapsed = currentTime - animation.startTime
      let animatedAlpha: CGFloat

      if elapsed < 0 {
        animatedAlpha = 0.0
      } else {
        let progress = min(max(elapsed / animation.duration, 0.0), 1.0)
        let easedProgress = easeOut(progress)
        animatedAlpha = easedProgress
      }

      let defaultColor = NSColor(Color.Theme.Foreground.Primary.Primary750)
      textStorage.enumerateAttribute(.foregroundColor, in: animation.range, options: []) { value, range, _ in
        let baseColor = (value as? NSColor) ?? defaultColor
        textStorage.addAttribute(.foregroundColor, value: baseColor.withAlphaComponent(animatedAlpha), range: range)
      }
    }
  }

  private func setUpDisplayLink() {
    let link = displayLink(
      target: self,
      selector: #selector(updateFadeAnimation)
    )
    link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
    link.add(to: .main, forMode: .common)
    fadeAnimationDisplayLink = link
  }

  private func tearDownDisplayLink() {
    fadeAnimationDisplayLink?.invalidate()
    fadeAnimationDisplayLink = nil
  }

  private func invalidateCachedSize() {
    cachedSize = nil
  }

  func setTextContextMenu(_ menu: TextContextMenu?) {
    textContextMenu = menu
  }

  func setMarkdownController(_ controller: MarkdownController?) {
    markdownController = controller
  }

  // MARK: - Link Clicks

  override func clicked(onLink link: Any, at charIndex: Int) {
    if let url = link as? URL {
      onUrlTap(url)
    } else if let string = link as? String, let url = URL(string: string) {
      onUrlTap(url)
    }
  }

  // MARK: - Context Menu

  override func menu(for event: NSEvent) -> NSMenu? {
    guard let textContextMenu, let textStorage else {
      return super.menu(for: event)
    }

    let selectedRange = self.selectedRange()
    let clampedRange = NSIntersectionRange(selectedRange, NSRange(location: 0, length: textStorage.length))
    let selectedText = textStorage.attributedSubstring(from: clampedRange).string

    let menu = NSMenu()

    // Add standard Copy item
    let copyItem = NSMenuItem(title: "Copy", action: #selector(copy(_:)), keyEquivalent: "c")
    menu.addItem(copyItem)
    menu.addItem(.separator())

    // Add custom groups
    for group in textContextMenu.menuGroups {
      if group.displayInline {
        for item in group.items {
          let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
          menuItem.representedObject = (item.id, selectedText)
          menuItem.target = self
          menuItem.action = #selector(contextMenuItemTapped(_:))
          menu.addItem(menuItem)
        }
      } else {
        let submenu = NSMenu(title: group.title ?? "")
        for item in group.items {
          let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
          menuItem.representedObject = (item.id, selectedText)
          menuItem.target = self
          menuItem.action = #selector(contextMenuItemTapped(_:))
          submenu.addItem(menuItem)
        }
        let submenuItem = NSMenuItem(title: group.title ?? "", action: nil, keyEquivalent: "")
        submenuItem.submenu = submenu
        menu.addItem(submenuItem)
      }
      menu.addItem(.separator())
    }

    // Notify controller of menu appearance
    if let markdownController {
      for group in textContextMenu.menuGroups {
        for item in group.items {
          markdownController.onContextMenuAppear(id: item.id, selectedContent: selectedText)
        }
      }
    }

    return menu
  }

  @objc private func contextMenuItemTapped(_ sender: NSMenuItem) {
    guard let (id, selectedText) = sender.representedObject as? (String, String) else { return }
    markdownController?.onContextMenuTap(id: id, selectedContent: selectedText)
  }
}

// MARK: - NSTextViewDelegate

extension ParagraphNSView: NSTextViewDelegate {
  func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
    if let url = link as? URL {
      onUrlTap(url)
      return true
    } else if let string = link as? String, let url = URL(string: string) {
      onUrlTap(url)
      return true
    }
    return false
  }
}

// MARK: - macOS Latex View Provider

final class LatexViewProviderMac: NSTextAttachmentViewProvider {
  private let latex: String
  private let fontSize: CGFloat
  private let textColor: NSColor
  private static let jsonDecoder = JSONDecoder()

  required override init(textAttachment attachment: NSTextAttachment,
                         parentView: NSView?,
                         textLayoutManager: NSTextLayoutManager?,
                         location: any NSTextLocation) {

    var tempLatex = ""
    var tempFontSize = Typography.base.uiFont.pointSize
    var tempTextColor: NSColor = NSColor(Color.Theme.Foreground.Primary.Primary750)
    if let data = attachment.contents {
      if let attachmentData = try? Self.jsonDecoder.decode(LatexAttachmentData.self, from: data) {
        tempLatex = attachmentData.latex
        tempFontSize = attachmentData.fontSize
        tempTextColor = attachmentData.resolvedTextColor
      }
    }
    latex = tempLatex
    fontSize = tempFontSize
    textColor = tempTextColor

    super.init(textAttachment: attachment,
               parentView: parentView,
               textLayoutManager: textLayoutManager,
               location: location)

    tracksTextAttachmentViewBounds = true
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
    mathLabel.layout()
    let height = mathLabel.bounds.height.rounded(.up) + 1.0
    let font = attributes[.font] as? NSFont ?? NSFont.systemFont(ofSize: fontSize)
    let yOffset = (font.xHeight - height) / 2.0
    return CGRect(x: 0, y: yOffset, width: mathLabel.bounds.width.rounded(.up), height: height)
  }
}

// MARK: - macOS Citation View Provider

private final class AttachmentCitationLabelMac: NSTextField {
  private let textInsets = InlineCitationAttachment.textInsets

  init(title: String, font: NSFont, textColor: NSColor, backgroundColor: NSColor) {
    super.init(frame: .zero)
    self.isBordered = false
    self.isEditable = false
    self.isSelectable = false
    self.drawsBackground = true
    self.wantsLayer = true
    self.layer?.cornerRadius = InlineCitationAttachment.cornerRadius
    self.layer?.masksToBounds = true
    self.layer?.backgroundColor = backgroundColor.cgColor
    self.font = font
    self.textColor = textColor
    self.alignment = .center
    self.maximumNumberOfLines = 1
    self.stringValue = title

    setAccessibilityElement(false)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: NSSize {
    let size = super.intrinsicContentSize
    return NSSize(
      width: size.width + textInsets.left + textInsets.right,
      height: size.height + textInsets.top + textInsets.bottom
    )
  }
}

final class InlineCitationViewProviderMac: NSTextAttachmentViewProvider {
  required override init(
    textAttachment attachment: NSTextAttachment,
    parentView: NSView?,
    textLayoutManager: NSTextLayoutManager?,
    location: any NSTextLocation
  ) {
    super.init(
      textAttachment: attachment,
      parentView: parentView,
      textLayoutManager: textLayoutManager,
      location: location
    )
    tracksTextAttachmentViewBounds = true
  }

  override func loadView() {
    guard let attachment = textAttachment as? InlineCitationAttachment,
          let data = attachment.citationData else {
      return
    }

    let font = NSFont.systemFont(ofSize: attachment.font.pointSize, weight: .regular)
    let textColor = attachment.textColor
    let bgColor = attachment.backgroundColor

    self.view = AttachmentCitationLabelMac(
      title: data.title,
      font: font,
      textColor: textColor,
      backgroundColor: bgColor
    )
  }
}
#endif
