//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

#if canImport(AppKit)
import AppKit

class ParagraphNSViewCache {
  @WithLock
  private var cachedViews: [ParagraphNSView] = []
  private let maxCacheSize = 50

  private init() {}

  static let shared: ParagraphNSViewCache = .init()

  func createOrReuseParagraphNSView(contents: NSMutableAttributedString, lineSpacing: CGFloat?) -> ParagraphNSView {
    if let availableView = findAvailableCachedView() {
      return availableView
    }

    let newView = ParagraphNSView()
    if $cachedViews.read(closure: { $0.count }) < maxCacheSize {
      $cachedViews.mutate { $0.append(newView) }
    }
    return newView
  }

  private func findAvailableCachedView() -> ParagraphNSView? {
    $cachedViews.read(closure: { cachedView in
      return cachedView.first { view in
        view.superview == nil && view.window == nil
      }
    })
  }
}
#endif
