//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

#if canImport(UIKit) || canImport(AppKit)
import CoreImage
import Foundation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct CharacterStreamingGlyphAnimationFrame: Equatable {
  let range: NSRange
  let transform: CharacterStreamingTransform
  let startTime: CFTimeInterval
}

struct CharacterStreamingGlyphBlend: Equatable {
  let blurredAlpha: CGFloat
  let sharpAlpha: CGFloat
  let blurRadius: CGFloat

  static func value(
    for transform: CharacterStreamingTransform
  ) -> CharacterStreamingGlyphBlend {
    let blurFraction = min(
      max(
        transform.blurRadius
          / ParagraphAnimationConstants.initialCharacterBlurRadius,
        0
      ),
      1
    )
    return CharacterStreamingGlyphBlend(
      blurredAlpha: transform.opacity * blurFraction,
      sharpAlpha: transform.opacity * (1 - blurFraction),
      blurRadius: transform.blurRadius
    )
  }
}

final class CharacterStreamingLayoutManager: NSLayoutManager {
  private static let blurContext = CIContext(
    options: [.cacheIntermediates: false]
  )
  private var animationFrames: [CharacterStreamingGlyphAnimationFrame] = []

  func updateAnimations(
    _ animations: [CharacterStreamingAnimation],
    at time: CFTimeInterval
  ) {
    updateAnimationFrames(animations.map {
      CharacterStreamingGlyphAnimationFrame(
        range: $0.range,
        transform: $0.transform(at: time),
        startTime: $0.startTime
      )
    })
  }

  func updateAnimationFrames(
    _ frames: [CharacterStreamingGlyphAnimationFrame]
  ) {
    animationFrames = frames
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

    let glyphFrames: [CharacterStreamingGlyphAnimationFrame] = animationFrames.compactMap { frame in
      let frameGlyphRange = glyphRange(
        forCharacterRange: frame.range,
        actualCharacterRange: nil
      )
      let visibleRange = NSIntersectionRange(frameGlyphRange, glyphsToShow)
      guard visibleRange.length > 0 else { return nil }
      return CharacterStreamingGlyphAnimationFrame(
        range: visibleRange,
        transform: frame.transform,
        startTime: frame.startTime
      )
    }
    let shapedClusters = Self.coalescedGlyphFrames(glyphFrames)
    var nextGlyphLocation = glyphsToShow.location
    let glyphEnd = NSMaxRange(glyphsToShow)

    for cluster in shapedClusters {
      if nextGlyphLocation < cluster.range.location {
        super.drawGlyphs(
          forGlyphRange: NSRange(
            location: nextGlyphLocation,
            length: cluster.range.location - nextGlyphLocation
          ),
          at: origin
        )
      }

      let transformedRange = NSIntersectionRange(
        cluster.range,
        NSRange(
          location: nextGlyphLocation,
          length: max(0, glyphEnd - nextGlyphLocation)
        )
      )
      if transformedRange.length > 0 {
        drawTransformedGlyphs(
          in: transformedRange,
          at: origin,
          transform: cluster.transform
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

  static func coalescedGlyphFrames(
    _ frames: [CharacterStreamingGlyphAnimationFrame]
  ) -> [CharacterStreamingGlyphAnimationFrame] {
    let sortedFrames = frames.sorted {
      if $0.range.location == $1.range.location {
        $0.startTime < $1.startTime
      } else {
        $0.range.location < $1.range.location
      }
    }
    var clusters: [CharacterStreamingGlyphAnimationFrame] = []
    for frame in sortedFrames {
      guard let last = clusters.last,
            NSIntersectionRange(last.range, frame.range).length > 0 else {
        clusters.append(frame)
        continue
      }
      let newest = frame.startTime >= last.startTime ? frame : last
      clusters[clusters.count - 1] = CharacterStreamingGlyphAnimationFrame(
        range: NSUnionRange(last.range, frame.range),
        transform: newest.transform,
        startTime: newest.startTime
      )
    }
    return clusters
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
    let blend = CharacterStreamingGlyphBlend.value(for: transform)

    if blend.blurredAlpha > 0, blend.blurRadius > 0 {
      drawGlyphPass(
        in: glyphRange,
        at: origin,
        context: context,
        bounds: bounds,
        anchor: anchor,
        transform: transform,
        alpha: blend.blurredAlpha,
        blurRadius: blend.blurRadius
      )
    }
    if blend.sharpAlpha > 0 {
      drawGlyphPass(
        in: glyphRange,
        at: origin,
        context: context,
        bounds: bounds,
        anchor: anchor,
        transform: transform,
        alpha: blend.sharpAlpha,
        blurRadius: nil
      )
    }
  }

  private func drawGlyphPass(
    in glyphRange: NSRange,
    at origin: CGPoint,
    context: CGContext,
    bounds: CGRect,
    anchor: CGPoint,
    transform: CharacterStreamingTransform,
    alpha: CGFloat,
    blurRadius: CGFloat?
  ) {
    context.saveGState()
    context.translateBy(
      x: 0,
      y: Self.baselineTranslation(transform.baselineOffset)
    )
    context.translateBy(x: anchor.x, y: anchor.y)
    context.scaleBy(x: transform.scale, y: transform.scale)
    context.translateBy(x: -anchor.x, y: -anchor.y)

    if let blurRadius, blurRadius > 0 {
      drawBlurredGlyphs(
        in: glyphRange,
        at: origin,
        bounds: bounds,
        radius: blurRadius,
        scale: Self.backingScale(for: context),
        alpha: alpha
      )
    } else {
      context.setAlpha(alpha)
      super.drawGlyphs(forGlyphRange: glyphRange, at: origin)
    }

    context.restoreGState()
  }

  private func drawBlurredGlyphs(
    in glyphRange: NSRange,
    at origin: CGPoint,
    bounds: CGRect,
    radius: CGFloat,
    scale: CGFloat,
    alpha: CGFloat
  ) {
    let padding = radius * 4
    let imageBounds = bounds.insetBy(dx: -padding, dy: -padding)
    guard imageBounds.width > 0,
          imageBounds.height > 0,
          let sourceImage = glyphImage(
            in: glyphRange,
            at: origin,
            bounds: imageBounds,
            scale: scale
          ) else {
      super.drawGlyphs(forGlyphRange: glyphRange, at: origin)
      return
    }

    let inputImage = CIImage(cgImage: sourceImage)
    guard let filter = CIFilter(name: "CIGaussianBlur") else {
      super.drawGlyphs(forGlyphRange: glyphRange, at: origin)
      return
    }
    filter.setValue(inputImage, forKey: kCIInputImageKey)
    filter.setValue(radius * scale, forKey: kCIInputRadiusKey)
    guard let outputImage = filter.outputImage?.cropped(to: inputImage.extent),
          let blurredImage = Self.blurContext.createCGImage(
            outputImage,
            from: inputImage.extent
          ) else {
      super.drawGlyphs(forGlyphRange: glyphRange, at: origin)
      return
    }

    #if canImport(UIKit)
    UIImage(
      cgImage: blurredImage,
      scale: scale,
      orientation: .up
    ).draw(
      in: imageBounds,
      blendMode: .normal,
      alpha: alpha
    )
    #elseif canImport(AppKit)
    NSImage(
      cgImage: blurredImage,
      size: imageBounds.size
    ).draw(
      in: imageBounds,
      from: .zero,
      operation: .sourceOver,
      fraction: alpha,
      respectFlipped: true,
      hints: nil
    )
    #endif
  }

  private func glyphImage(
    in glyphRange: NSRange,
    at origin: CGPoint,
    bounds: CGRect,
    scale: CGFloat
  ) -> CGImage? {
    #if canImport(UIKit)
    let format = UIGraphicsImageRendererFormat()
    format.opaque = false
    format.scale = scale
    let image = UIGraphicsImageRenderer(
      size: bounds.size,
      format: format
    ).image { rendererContext in
      rendererContext.cgContext.translateBy(
        x: -bounds.minX,
        y: -bounds.minY
      )
      drawSourceGlyphs(in: glyphRange, at: origin)
    }
    return image.cgImage
    #elseif canImport(AppKit)
    let image = NSImage(size: bounds.size, flipped: true) { _ in
      guard let context = NSGraphicsContext.current?.cgContext else {
        return false
      }
      context.translateBy(x: -bounds.minX, y: -bounds.minY)
      self.drawSourceGlyphs(in: glyphRange, at: origin)
      return true
    }
    var proposedRect = CGRect(origin: .zero, size: bounds.size)
    return image.cgImage(
      forProposedRect: &proposedRect,
      context: nil,
      hints: nil
    )
    #endif
  }

  private func drawSourceGlyphs(
    in glyphRange: NSRange,
    at origin: CGPoint
  ) {
    super.drawGlyphs(forGlyphRange: glyphRange, at: origin)
  }

  private static func backingScale(for context: CGContext) -> CGFloat {
    let transform = context.ctm
    let xScale = hypot(transform.a, transform.c)
    let yScale = hypot(transform.b, transform.d)
    return max(1, max(xScale, yScale))
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
