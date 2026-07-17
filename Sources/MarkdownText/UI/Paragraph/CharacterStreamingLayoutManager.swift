//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

#if canImport(UIKit) || canImport(AppKit)
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

final class CharacterStreamingLayoutManager: NSLayoutManager {
  private var animationFrames: [(range: NSRange, transform: CharacterStreamingTransform)] = []

  func updateAnimations(
    _ animations: [CharacterStreamingAnimation],
    at time: CFTimeInterval
  ) {
    animationFrames = animations.map {
      (range: $0.range, transform: $0.transform(at: time))
    }
    invalidateDisplay(forCharacterRange: NSRange(
      location: 0,
      length: textStorage?.length ?? 0
    ))
  }

  func clearAnimations() {
    animationFrames.removeAll()
    invalidateDisplay(forCharacterRange: NSRange(
      location: 0,
      length: textStorage?.length ?? 0
    ))
  }

  override func drawGlyphs(
    forGlyphRange glyphsToShow: NSRange,
    at origin: CGPoint
  ) {
    guard !animationFrames.isEmpty else {
      super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
      return
    }

    let sortedFrames = animationFrames.sorted {
      $0.range.location < $1.range.location
    }
    var nextGlyphLocation = glyphsToShow.location
    let glyphEnd = NSMaxRange(glyphsToShow)

    for frame in sortedFrames {
      let frameGlyphRange = glyphRange(
        forCharacterRange: frame.range,
        actualCharacterRange: nil
      )
      let visibleFrameRange = NSIntersectionRange(frameGlyphRange, glyphsToShow)
      guard visibleFrameRange.length > 0 else {
        continue
      }

      if nextGlyphLocation < visibleFrameRange.location {
        super.drawGlyphs(
          forGlyphRange: NSRange(
            location: nextGlyphLocation,
            length: visibleFrameRange.location - nextGlyphLocation
          ),
          at: origin
        )
      }

      let transformedRange = NSIntersectionRange(
        visibleFrameRange,
        NSRange(
          location: nextGlyphLocation,
          length: max(0, glyphEnd - nextGlyphLocation)
        )
      )
      if transformedRange.length > 0 {
        drawTransformedGlyphs(
          in: transformedRange,
          at: origin,
          transform: frame.transform
        )
        nextGlyphLocation = NSMaxRange(transformedRange)
      }
    }

    if nextGlyphLocation < glyphEnd {
      super.drawGlyphs(
        forGlyphRange: NSRange(
          location: nextGlyphLocation,
          length: glyphEnd - nextGlyphLocation
        ),
        at: origin
      )
    }
  }

  private func drawTransformedGlyphs(
    in glyphRange: NSRange,
    at origin: CGPoint,
    transform: CharacterStreamingTransform
  ) {
    guard let context = currentGraphicsContext(),
          let textContainer = textContainer(
            forGlyphAt: glyphRange.location,
            effectiveRange: nil
          ) else {
      super.drawGlyphs(forGlyphRange: glyphRange, at: origin)
      return
    }

    let bounds = boundingRect(
      forGlyphRange: glyphRange,
      in: textContainer
    ).offsetBy(dx: origin.x, dy: origin.y)
    let anchor = CGPoint(x: bounds.midX, y: bounds.maxY)

    context.saveGState()
    context.setAlpha(transform.opacity)
    context.translateBy(
      x: 0,
      y: Self.baselineTranslation(transform.baselineOffset)
    )
    context.translateBy(x: anchor.x, y: anchor.y)
    context.scaleBy(x: transform.scale, y: transform.scale)
    context.translateBy(x: -anchor.x, y: -anchor.y)
    super.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    context.restoreGState()
  }

  private func currentGraphicsContext() -> CGContext? {
    #if canImport(UIKit)
    UIGraphicsGetCurrentContext()
    #elseif canImport(AppKit)
    NSGraphicsContext.current?.cgContext
    #endif
  }

  static func baselineTranslation(_ offset: CGFloat) -> CGFloat {
    offset
  }
}
#endif
