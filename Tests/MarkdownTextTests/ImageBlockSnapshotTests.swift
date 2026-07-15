//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftUI
@testable import SwiftStreamingMarkdown
import XCTest

/// Snapshot coverage for a resolved block-level image, rendered from an image
/// bundled with the test target through the same presentation the library
/// applies to loaded images (`Image(mdImage:)` + `.resizable().scaledToFit()`).
final class ImageBlockSnapshotTests: SnapshotTestCase {

  /// Loads the bundled test image, failing the test if it is missing.
  private func bundledImage(
    _ name: String,
    ext: String = "png",
    file: StaticString = #file,
    line: UInt = #line
  ) -> MDImage {
    guard
      let url = Bundle.module.url(forResource: name, withExtension: ext),
      let data = try? Data(contentsOf: url),
      let image = MDImage(data: data)
    else {
      fatalError("Missing bundled test image: \(name).\(ext)")
    }
    return image
  }

  func test_bundled_image_renders_full_width() throws {
    let image = bundledImage("sample-landscape")
    let view = CanvasView {
      Image(mdImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity, alignment: .center)
    }

    assert(view)
  }
}
