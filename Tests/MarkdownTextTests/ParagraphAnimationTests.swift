//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
@testable import SwiftStreamingMarkdown
import Testing

@Suite("Paragraph reveal planning")
struct ParagraphAnimationTests {
  @Test("Reveals only the appended suffix")
  func appendedSuffix() throws {
    let previous = "Stable text"
    let updated = "\(previous) fades in"
    let plan = try #require(
      ParagraphRevealPlan.appendedText(previousText: previous, newText: updated)
    )
    let coveredRange = try #require(plan.coveredRange)

    #expect(coveredRange.location == (previous as NSString).length)
    #expect((updated as NSString).substring(with: coveredRange) == " fades in")
    #expect(plan.segments.first?.delay == 0)
    #expect(plan.segments.last?.delay == ParagraphAnimationConstants.revealStaggerDuration)
  }

  @Test("Does not animate replacements or style-only updates")
  func nonAppendUpdates() {
    #expect(
      ParagraphRevealPlan.appendedText(
        previousText: "Streaming *text",
        newText: "Streaming text"
      ) == nil
    )
    #expect(
      ParagraphRevealPlan.appendedText(
        previousText: "Unchanged",
        newText: "Unchanged"
      ) == nil
    )
  }

  @Test("Uses UTF-16 ranges without splitting composed characters")
  func composedCharacters() throws {
    let previous = "Hello 👨‍👩‍👧‍👦"
    let suffix = " café 🧮"
    let updated = previous + suffix
    let plan = try #require(
      ParagraphRevealPlan.appendedText(previousText: previous, newText: updated)
    )
    let coveredRange = try #require(plan.coveredRange)

    #expect(coveredRange.location == (previous as NSString).length)
    #expect((updated as NSString).substring(with: coveredRange) == suffix)
    #expect(plan.segments.allSatisfy { segment in
      let composedRange = (updated as NSString).rangeOfComposedCharacterSequences(
        for: segment.range
      )
      return composedRange == segment.range
    })
  }

  @Test("Does not animate when an append extends the previous grapheme")
  func extendedPreviousGrapheme() {
    #expect(
      ParagraphRevealPlan.appendedText(
        previousText: "Cafe",
        newText: "Cafe\u{301}"
      ) == nil
    )
    #expect(
      ParagraphRevealPlan.appendedText(
        previousText: "👨",
        newText: "👨‍👩"
      ) == nil
    )
  }

  @Test("Bounds work for very large chunks")
  func boundedSegments() throws {
    let suffix = String(repeating: "streaming ", count: 10_000)
    let plan = try #require(
      ParagraphRevealPlan.appendedText(previousText: "Start: ", newText: "Start: \(suffix)")
    )

    #expect(plan.segments.count <= ParagraphAnimationConstants.maximumSegmentCount)
    #expect(plan.coveredRange?.length == (suffix as NSString).length)
  }

  @Test("Carries unfinished segments across rapid updates with bounded work")
  func rapidUpdates() throws {
    let firstPlan = try #require(
      ParagraphRevealPlan.appendedText(previousText: "", newText: "First streamed chunk")
    )
    let firstAnimation = FadeAnimationData(
      plan: firstPlan,
      startTime: 0,
      contentLength: ("First streamed chunk" as NSString).length
    )
    let secondText = "First streamed chunk plus another streamed chunk"
    let secondPlan = try #require(
      ParagraphRevealPlan.appendedText(
        previousText: "First streamed chunk",
        newText: secondText
      )
    )
    let secondAnimation = FadeAnimationData(
      plan: secondPlan,
      startTime: 0.15,
      previousAnimation: firstAnimation,
      contentLength: (secondText as NSString).length
    )

    #expect(secondAnimation.segments.contains { $0.range.location == 0 })
    #expect(secondAnimation.segments.contains {
      $0.range.location >= ("First streamed chunk" as NSString).length
    })
    #expect(
      secondAnimation.segments.count <= ParagraphAnimationConstants.maximumSegmentCount
    )
  }

  @Test("Reduce Motion disables the reveal")
  func reduceMotion() {
    #expect(shouldRevealAppendedText(isConfigured: true, reduceMotion: false))
    #expect(!shouldRevealAppendedText(isConfigured: true, reduceMotion: true))
    #expect(!shouldRevealAppendedText(isConfigured: false, reduceMotion: false))
  }
}

private extension ParagraphRevealPlan {
  var coveredRange: NSRange? {
    guard let first = segments.first, let last = segments.last else {
      return nil
    }
    return NSRange(
      location: first.range.location,
      length: NSMaxRange(last.range) - first.range.location
    )
  }
}
