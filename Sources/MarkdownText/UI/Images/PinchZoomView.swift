//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftUI

/// A zoomable, pannable image view supporting pinch-to-zoom, double-tap zoom,
/// and swipe-to-dismiss. Used by the built-in fullscreen image viewer.
///
/// Adapted from the reusable `PinchZoomView` in Microsoft's CopilotNative app,
/// with app-specific dependencies (design system, screen-size listener)
/// removed so it works cross-platform.
struct PinchZoomView: View {
  static let dismissVelocity = 5000.0
  static let minZoomScale: CGFloat = 1.0
  static let maxZoomScale: CGFloat = 4.0
  static let doubleTapZoomScale: CGFloat = 2.0
  static let bounceDistance: CGFloat = 80.0
  static let elasticityFactor: CGFloat = 0.4

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  @State private var canSwipeToDismiss = true
  @State private var velocity = CGSize.zero
  @State private var lastDragTime: Date?

  let image: Image
  let onSwipeToDismiss: () -> Void

  init(image: Image, onSwipeToDismiss: @escaping () -> Void) {
    self.image = image
    self.onSwipeToDismiss = onSwipeToDismiss
  }

  private func magnitude(of size: CGSize) -> Double {
    return sqrt(size.width * size.width + size.height * size.height)
  }

  var body: some View {
    GeometryReader { geometry in
      image
        .resizable()
        .aspectRatio(contentMode: .fit)
        .scaleEffect(scale)
        .offset(offset)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .onTapGesture(count: 2) { location in
          handleDoubleTap(at: location, in: geometry)
        }
        .gesture(
          SimultaneousGesture(
            DragGesture()
              .onChanged { value in
                let newOffset = CGSize(width: value.translation.width + self.lastOffset.width, height: value.translation.height + self.lastOffset.height)
                self.offset = elasticOffset(newOffset, geometry: geometry)

                if canSwipeToDismiss {
                  if let lastTime = lastDragTime {
                    let timeDiff = value.time.timeIntervalSince(lastTime)
                    velocity = CGSize(
                      width: value.translation.width / CGFloat(timeDiff),
                      height: value.translation.height / CGFloat(timeDiff)
                    )
                  }
                }
                lastDragTime = value.time
              }
              .onEnded { _ in
                if isOutOfBounds(self.offset, geometry: geometry), !canSwipeToDismiss {
                  resetToClampOffset(in: geometry)
                }

                self.lastOffset = self.offset

                guard canSwipeToDismiss else {
                  return
                }
                if magnitude(of: velocity) > Self.dismissVelocity {
                  onSwipeToDismiss()
                } else {
                  resetToOriginalSize()
                }
              },
            MagnificationGesture()
              .onChanged { value in
                let delta = value / self.lastScale
                self.lastScale = value
                let newScale = self.scale * delta
                self.scale = min(max(newScale, Self.minZoomScale), Self.maxZoomScale)
                self.canSwipeToDismiss = self.scale <= Self.minZoomScale
              }
              .onEnded { _ in
                self.lastScale = Self.minZoomScale

                if canSwipeToDismiss {
                  resetToOriginalSize()
                } else if isOutOfBounds(self.offset, geometry: geometry) {
                  resetToClampOffset(in: geometry)
                }
              }
          )
        )
    }
  }

  private func handleDoubleTap(at location: CGPoint, in geometry: GeometryProxy) {
    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
      if scale > Self.minZoomScale {
        resetToOriginalSize()
      } else {
        canSwipeToDismiss = false
        scale = Self.doubleTapZoomScale

        let imageCenter = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        let tapOffset = CGSize(
          width: (imageCenter.x - location.x) * (scale - 1),
          height: (imageCenter.y - location.y) * (scale - 1)
        )
        offset = tapOffset
        lastOffset = offset
      }
    }
  }

  private func resetToOriginalSize() {
    withAnimation(.easeInOut(duration: 0.25)) {
      scale = Self.minZoomScale
      lastScale = Self.minZoomScale
      offset = .zero
      lastOffset = .zero
      canSwipeToDismiss = true
    }
  }

  private func resetToClampOffset(in geometry: GeometryProxy) {
    withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)) {
      self.offset = clampOffset(self.offset, geometry: geometry)
    }
  }

  /// Calculate the maximum allowed offset for the current zoom scale.
  private func maxOffsets(in geometry: GeometryProxy) -> CGSize {
    // Calculate the actual size of the image at the current zoom scale
    let scaledWidth = geometry.size.width * scale
    let scaledHeight = geometry.size.height * scale

    // Calculate the maximum allowed offset (without elasticity)
    let maxOffsetX = (scaledWidth - geometry.size.width) / 2
    let maxOffsetY = (scaledHeight - geometry.size.height) / 2

    return CGSize(width: maxOffsetX, height: maxOffsetY)
  }

  private func elasticOffset(_ newOffset: CGSize, geometry: GeometryProxy) -> CGSize {
    if scale <= Self.minZoomScale {
      return newOffset
    }

    let maxOffset = maxOffsets(in: geometry)

    // Calculate elastic offset
    func applyElasticity(to value: CGFloat, max: CGFloat) -> CGFloat {
      if abs(value) <= max {
        return value
      } else {
        let excess = abs(value) - max
        let normalizedExcess = excess / Self.bounceDistance
        let dampingRatio: CGFloat
        if normalizedExcess <= 1.0 {
          // Use linear damping for short distances
          dampingRatio = Self.elasticityFactor * normalizedExcess * 0.6
        } else {
          // Use logarithmic damping for long distances
          dampingRatio = Self.elasticityFactor * (0.6 + 0.4 * log(normalizedExcess))
        }
        let dampedExcess = excess * dampingRatio
        return value < 0 ? -(max + dampedExcess) : (max + dampedExcess)
      }
    }

    return CGSize(
      width: applyElasticity(to: newOffset.width, max: maxOffset.width),
      height: applyElasticity(to: newOffset.height, max: maxOffset.height)
    )
  }

  private func clampOffset(_ newOffset: CGSize, geometry: GeometryProxy) -> CGSize {
    if scale <= Self.minZoomScale {
      return .zero
    }

    let maxOffset = maxOffsets(in: geometry)

    return CGSize(
      width: max(-maxOffset.width, min(maxOffset.width, newOffset.width)),
      height: max(-maxOffset.height, min(maxOffset.height, newOffset.height))
    )
  }

  private func isOutOfBounds(_ offset: CGSize, geometry: GeometryProxy) -> Bool {
    let clampedOffset = clampOffset(offset, geometry: geometry)
    return offset.width != clampedOffset.width || offset.height != clampedOffset.height
  }
}
