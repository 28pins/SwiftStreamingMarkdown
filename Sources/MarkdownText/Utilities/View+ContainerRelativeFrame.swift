//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftUI

extension View {

  /// Applies `containerRelativeFrame(_:alignment:_:)` where available, sizing the
  /// view relative to its container along the given `axes`.
  ///
  /// On platforms older than iOS 17 / macOS 14 the modifier is unavailable, so the
  /// view is returned unchanged.
  @ViewBuilder
  func containerRelativeFrameCompat(
    _ axes: Axis.Set,
    alignment: Alignment = .center,
    _ length: @escaping (CGFloat, Axis) -> CGFloat
  ) -> some View {
    if #available(iOS 17.0, macOS 14.0, *) {
      containerRelativeFrame(axes, alignment: alignment, length)
    } else {
      self
    }
  }
}
