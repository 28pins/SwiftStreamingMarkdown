//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
@testable import SwiftStreamingMarkdown
import Testing

@Suite("Character Streaming")
struct ParagraphAnimationTests {
  @Test("Releases exactly one grapheme and never batches at one timestamp")
  func releasesOneAtATime() throws {
    let state = CharacterStreamingState()
    state.update(target: attributed("abcd"), isComplete: false, at: 0)

    let first = try #require(state.releaseNext(at: 0))
    #expect(substring("abcd", in: first.range) == "a")
    #expect(state.visibleAttributedText.string == "a")
    #expect(state.releaseNext(at: 0) == nil)
    #expect(state.visibleAttributedText.string == "a")

    let second = try #require(state.releaseNext(at: 0.018))
    #expect(substring("abcd", in: second.range) == "b")
    #expect(state.visibleAttributedText.string == "ab")
  }

  @Test("Uses 18ms at low backlog and smoothly accelerates up to four times")
  func adaptiveCadence() {
    let low = CharacterStreamingState.releaseInterval(forBacklog: 1)
    let medium = CharacterStreamingState.releaseInterval(forBacklog: 32)
    let high = CharacterStreamingState.releaseInterval(forBacklog: 64)

    #expect(low == 0.018)
    #expect(medium < low)
    #expect(medium > high)
    #expect(abs(high - 0.0045) < 0.000_001)
  }

  @Test("Cadence returns toward 18ms while backlog drains")
  func cadenceSlowsWhileDraining() throws {
    let state = CharacterStreamingState()
    state.update(
      target: attributed(String(repeating: "a", count: 80)),
      isComplete: true,
      at: 0
    )
    let initialInterval = state.nextReleaseInterval

    for index in 0..<77 {
      _ = try #require(state.releaseNext(at: Double(index + 1)))
    }

    #expect(initialInterval < state.nextReleaseInterval)
    #expect(state.nextReleaseInterval == 0.018)
  }

  @Test("Withholds a terminal grapheme across chunks that extend it")
  func crossChunkContinuity() throws {
    let state = CharacterStreamingState()
    state.update(target: attributed("Cafe"), isComplete: false, at: 0)
    for time in [0.0, 0.018, 0.036] {
      _ = try #require(state.releaseNext(at: time))
    }
    #expect(state.visibleAttributedText.string == "Caf")
    #expect(!state.hasPendingGrapheme)

    let continued = "Cafe\u{301} "
    state.update(target: attributed(continued), isComplete: false, at: 0.05)
    let release = try #require(state.releaseNext(at: 0.054))

    #expect(substring(continued, in: release.range) == "e\u{301}")
    #expect(state.visibleAttributedText.string == "Cafe\u{301}")
    #expect(!state.hasPendingGrapheme)
  }

  @Test("Starts with the exact rise, grow, sharpen, and fade transform")
  func exactInitialTransform() {
    let transform = CharacterStreamingTransform.value(at: 0)

    #expect(transform.opacity == 0.08)
    #expect(transform.scale == 0.82)
    #expect(transform.baselineOffset == 3)
    #expect(transform.blurRadius == 3)
  }

  @Test("Settles exactly to the final transform after 260ms")
  func exactFinalTransform() {
    let animation = CharacterStreamingAnimation(
      range: NSRange(location: 0, length: 1),
      startTime: 1
    )
    let transform = animation.transform(
      at: 1 + ParagraphAnimationConstants.characterAnimationDuration
    )

    #expect(transform.opacity == 1)
    #expect(transform.scale == 1)
    #expect(transform.baselineOffset == 0)
    #expect(transform.blurRadius == 0)
    #expect(animation.isFinished(at: 1.26))
  }

  @Test("Releases Unicode composed character sequences intact")
  func unicodeComposedGraphemes() throws {
    let text = "👨‍👩‍👧‍👦e\u{301}🇺🇸X"
    let state = CharacterStreamingState()
    state.update(target: attributed(text), isComplete: false, at: 0)

    let family = try #require(state.releaseNext(at: 0))
    let accented = try #require(state.releaseNext(at: 0.018))
    let flag = try #require(state.releaseNext(at: 0.036))

    #expect(substring(text, in: family.range) == "👨‍👩‍👧‍👦")
    #expect(substring(text, in: accented.range) == "e\u{301}")
    #expect(substring(text, in: flag.range) == "🇺🇸")
    #expect(state.visibleAttributedText.string == "👨‍👩‍👧‍👦e\u{301}🇺🇸")
    #expect(!state.hasPendingGrapheme)
  }

  @Test("Reduce Motion settles Character Streaming immediately")
  func reduceMotion() {
    #expect(
      resolvedTextAnimation(.characterStreaming, reduceMotion: false)
        == .characterStreaming
    )
    #expect(
      resolvedTextAnimation(.characterStreaming, reduceMotion: true)
        == .none
    )
    #expect(resolvedTextAnimation(.fade, reduceMotion: true) == .none)
  }

  @Test("Completion drains the withheld terminal grapheme")
  func completionDrain() throws {
    let state = CharacterStreamingState()
    state.update(target: attributed("A"), isComplete: false, at: 0)
    #expect(!state.hasPendingGrapheme)
    #expect(state.releaseNext(at: 0) == nil)

    state.update(target: attributed("A"), isComplete: true, at: 0.1)
    #expect(state.hasPendingGrapheme)
    _ = try #require(state.releaseNext(at: 0.1))
    #expect(state.visibleAttributedText.string == "A")
    #expect(!state.hasPendingGrapheme)
  }

  @Test("Replacement rewinds to a composed prefix and restyling is retained")
  func replacementAndRestyle() throws {
    let state = CharacterStreamingState()
    state.update(target: attributed("abcX"), isComplete: false, at: 0)
    for time in [0.0, 0.018, 0.036] {
      _ = try #require(state.releaseNext(at: time))
    }
    #expect(state.visibleAttributedText.string == "abc")

    state.update(target: attributed("abZ!"), isComplete: false, at: 0.05)
    #expect(state.visibleAttributedText.string == "ab")
    _ = try #require(state.releaseNext(at: 0.054))
    #expect(state.visibleAttributedText.string == "abZ")

    let styleKey = NSAttributedString.Key("CharacterStreamingTests.style")
    let restyled = NSMutableAttributedString(string: "abZ!")
    restyled.addAttribute(
      styleKey,
      value: "updated",
      range: NSRange(location: 0, length: restyled.length)
    )
    state.update(target: restyled, isComplete: false, at: 0.06)

    #expect(
      state.visibleAttributedText.attribute(
        styleKey,
        at: 0,
        effectiveRange: nil
      ) as? String == "updated"
    )
  }

  @Test("Preserves attributed Markdown runs in released content")
  func attributedContent() throws {
    let styleKey = NSAttributedString.Key("CharacterStreamingTests.typography")
    let target = NSMutableAttributedString(string: "ab")
    target.addAttribute(
      styleKey,
      value: "bold-link",
      range: NSRange(location: 0, length: 1)
    )
    let state = CharacterStreamingState()
    state.update(target: target, isComplete: false, at: 0)
    _ = try #require(state.releaseNext(at: 0))

    #expect(
      state.visibleAttributedText.attribute(
        styleKey,
        at: 0,
        effectiveRange: nil
      ) as? String == "bold-link"
    )
  }

  @Test("Bounds active animation state under sustained backlog")
  func boundedAnimationState() throws {
    let state = CharacterStreamingState()
    state.update(
      target: attributed(String(repeating: "a", count: 100)),
      isComplete: true,
      at: 0
    )

    for index in 0..<100 {
      _ = try #require(state.releaseNext(at: Double(index) / 1_000))
    }

    #expect(
      state.activeAnimations.count
        == ParagraphAnimationConstants.maximumActiveCharacterAnimations
    )
  }

  @Test("Public style selection is explicit and type safe")
  func styleSelection() {
    let characterStreaming = MarkdownRenderConfig(
      textAnimation: .characterStreaming
    )
    let fade = characterStreaming.withTextAnimation(.fade)

    #expect(MarkdownRenderConfig.default.textAnimation == .none)
    #expect(characterStreaming.textAnimation == .characterStreaming)
    #expect(fade.textAnimation == .fade)
  }

  @Test("Standard fade still targets only appended content")
  func standardFadeAppend() throws {
    let previous = "Stable text"
    let updated = "\(previous) fades in"
    let plan = try #require(
      ParagraphRevealPlan.appendedText(
        previousText: previous,
        newText: updated
      )
    )
    let coveredRange = try #require(plan.coveredRange)

    #expect(coveredRange.location == (previous as NSString).length)
    #expect(substring(updated, in: coveredRange) == " fades in")
    #expect(plan.segments.first?.delay == 0)
    #expect(
      plan.segments.last?.delay
        == ParagraphAnimationConstants.fadeStaggerDuration
    )
  }
}

private func attributed(_ text: String) -> NSAttributedString {
  NSAttributedString(string: text)
}

private func substring(_ text: String, in range: NSRange) -> String {
  (text as NSString).substring(with: range)
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
