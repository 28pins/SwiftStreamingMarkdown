//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

#if os(macOS)
import AppKit

class ParagraphNSViewCache {
  private let lock = NSLock()
  private var cachedViews: [ParagraphNSView] = []
  private let maxCacheSize = 50

  private init() {}

  static let shared: ParagraphNSViewCache = .init()

  func createOrReuseParagraphNSView(contents: NSMutableAttributedString, lineSpacing: CGFloat?) -> ParagraphNSView {
    if let availableView = findAvailableCachedView() {
      return availableView
    }

    let newView = ParagraphNSView()
    lock.lock()
    if cachedViews.count < maxCacheSize {
      cachedViews.append(newView)
    }
    lock.unlock()
    return newView
  }

  private func findAvailableCachedView() -> ParagraphNSView? {
    lock.lock()
    defer { lock.unlock() }
    return cachedViews.first { view in
      view.superview == nil && view.window == nil
    }
  }
}
#endif
