//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation

enum ParagraphAnimationConstants {
  static let fadeInDuration: CFTimeInterval = 0.45
  static let revealStaggerDuration: CFTimeInterval = 0.12
  static let targetSegmentLength = 8
  static let maximumSegmentCount = 24
}

struct ParagraphRevealSegment: Equatable {
  let range: NSRange
  let delay: CFTimeInterval
}

struct ParagraphRevealPlan: Equatable {
  let segments: [ParagraphRevealSegment]
  let duration: CFTimeInterval

  static func appendedText(previousText: String, newText: String) -> ParagraphRevealPlan? {
    let previous = previousText as NSString
    let updated = newText as NSString

    guard updated.length > previous.length,
          updated.substring(with: NSRange(location: 0, length: previous.length)) == previousText else {
      return nil
    }
    let firstAppendedCharacter = updated.rangeOfComposedCharacterSequence(
      at: previous.length
    )
    guard firstAppendedCharacter.location == previous.length else {
      return nil
    }

    let appendedRange = NSRange(
      location: previous.length,
      length: updated.length - previous.length
    )
    let preferredSegmentCount = max(
      1,
      Int(ceil(Double(appendedRange.length) / Double(ParagraphAnimationConstants.targetSegmentLength)))
    )
    let segmentCount = min(
      ParagraphAnimationConstants.maximumSegmentCount,
      preferredSegmentCount
    )
    let ranges = segmentRanges(
      in: updated,
      appendedRange: appendedRange,
      segmentCount: segmentCount
    )
    let delayStep = ranges.count > 1
      ? ParagraphAnimationConstants.revealStaggerDuration / Double(ranges.count - 1)
      : 0
    let segments = ranges.enumerated().map { index, range in
      ParagraphRevealSegment(range: range, delay: Double(index) * delayStep)
    }
    let duration = (segments.last?.delay ?? 0) + ParagraphAnimationConstants.fadeInDuration
    return ParagraphRevealPlan(segments: segments, duration: duration)
  }

  private static func segmentRanges(
    in string: NSString,
    appendedRange: NSRange,
    segmentCount: Int
  ) -> [NSRange] {
    guard segmentCount > 1 else {
      return [appendedRange]
    }

    let end = NSMaxRange(appendedRange)
    var segmentStart = appendedRange.location
    var ranges: [NSRange] = []
    ranges.reserveCapacity(segmentCount)

    for index in 1..<segmentCount {
      let target = appendedRange.location + appendedRange.length * index / segmentCount
      let composedCharacterRange = string.rangeOfComposedCharacterSequence(
        at: min(target, end - 1)
      )
      let boundary = min(end, max(segmentStart, NSMaxRange(composedCharacterRange)))
      guard boundary > segmentStart, boundary < end else {
        continue
      }
      ranges.append(NSRange(location: segmentStart, length: boundary - segmentStart))
      segmentStart = boundary
    }

    ranges.append(NSRange(location: segmentStart, length: end - segmentStart))
    return ranges
  }
}

struct FadeAnimationSegment {
  let range: NSRange
  let startTime: CFTimeInterval
}

struct FadeAnimationData {
  let segments: [FadeAnimationSegment]

  init(
    plan: ParagraphRevealPlan,
    startTime: CFTimeInterval,
    previousAnimation: FadeAnimationData? = nil,
    contentLength: Int
  ) {
    let unfinishedSegments = previousAnimation?.segments.filter {
      startTime < $0.startTime + ParagraphAnimationConstants.fadeInDuration
        && NSMaxRange($0.range) <= contentLength
    } ?? []
    let appendedSegments = plan.segments.map {
      FadeAnimationSegment(range: $0.range, startTime: startTime + $0.delay)
    }
    segments = Array(
      (unfinishedSegments + appendedSegments)
        .suffix(ParagraphAnimationConstants.maximumSegmentCount)
    )
  }

  var endTime: CFTimeInterval {
    (segments.map(\.startTime).max() ?? 0) + ParagraphAnimationConstants.fadeInDuration
  }
}

func shouldRevealAppendedText(isConfigured: Bool, reduceMotion: Bool) -> Bool {
  isConfigured && !reduceMotion
}

/// Cubic Bezier ease-out curve shared between iOS and macOS paragraph views.
func paragraphEaseOut(_ t: CGFloat) -> CGFloat {
  let c2: CGFloat = 0.1
  let c4: CGFloat = 1.0

  let t2 = t * t
  let t3 = t2 * t
  let mt = 1 - t
  let mt2 = mt * mt

  return 3 * mt2 * t * c2 + 3 * mt * t2 * c4 + t3
}
