//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class ParagraphViewCache {
  #if canImport(UIKit)
  @WithLock
  private var cachedViews: [ParagraphUIView] = []
  #elseif canImport(AppKit)
  @WithLock
  private var cachedViews: [ParagraphNSView] = []
  #endif

  private let maxCacheSize = 50

  private init() {}

  static let shared: ParagraphViewCache = .init()

  #if canImport(UIKit)
  func createOrReuseView(contents: NSMutableAttributedString, lineSpacing: CGFloat?) -> ParagraphUIView {
    if let availableView = findAvailableCachedView() {
      return availableView
    }
    let newView = ParagraphUIView()
    if $cachedViews.read(closure: { $0.count }) < maxCacheSize {
      $cachedViews.mutate { $0.append(newView) }
    }
    return newView
  }
  #elseif canImport(AppKit)
  func createOrReuseView(contents: NSMutableAttributedString, lineSpacing: CGFloat?) -> ParagraphNSView {
    if let availableView = findAvailableCachedView() {
      return availableView
    }
    let newView = ParagraphNSView()
    if $cachedViews.read(closure: { $0.count }) < maxCacheSize {
      $cachedViews.mutate { $0.append(newView) }
    }
    return newView
  }
  #endif

  #if canImport(UIKit)
  private func findAvailableCachedView() -> ParagraphUIView? {
    $cachedViews.read(closure: { cachedView in
      cachedView.first { view in
        view.superview == nil && view.window == nil
      }
    })
  }
  #elseif canImport(AppKit)
  private func findAvailableCachedView() -> ParagraphNSView? {
    $cachedViews.read(closure: { cachedView in
      cachedView.first { view in
        view.superview == nil && view.window == nil
      }
    })
  }
  #endif
}
