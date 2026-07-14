//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

@testable import SwiftStreamingMarkdown
import XCTest

final class ImageTapTests: XCTestCase {

  private func url(_ string: String) -> URL {
    guard let url = URL(string: string) else {
      fatalError("Invalid test URL: \(string)")
    }
    return url
  }

  func test_markdownImage_maps_each_resolved_source() {
    XCTAssertEqual(
      ImageData(source: ImageData.Source.remote(url("https://example.com/a.png")), alt: "a").markdownImage,
      MarkdownImage(source: MarkdownImage.Source.remote(url("https://example.com/a.png")), alt: "a")
    )
    XCTAssertEqual(
      ImageData(source: ImageData.Source.assetCatalog(name: "Images/logo"), alt: "b").markdownImage,
      MarkdownImage(source: MarkdownImage.Source.assetCatalog(name: "Images/logo"), alt: "b")
    )
    XCTAssertEqual(
      ImageData(source: ImageData.Source.bundledResource(fileName: "logo", ext: "png"), alt: "c").markdownImage,
      MarkdownImage(source: MarkdownImage.Source.bundledResource(fileName: "logo", ext: "png"), alt: "c")
    )
  }

  func test_markdownImage_is_nil_without_a_resolved_source() {
    XCTAssertNil(ImageData(source: nil, alt: "d").markdownImage)
  }

  func test_controller_forwards_image_tap_to_listener() async {
    let listener = RecordingMarkdownListener()
    let controller = MarkdownController(listener: listener)
    let image = MarkdownImage(source: MarkdownImage.Source.assetCatalog(name: "Images/logo"), alt: "logo")

    controller.onImageTap(image: image)

    let received = await listener.nextImageTap()
    XCTAssertEqual(received, image)
  }
}

/// Minimal `MarkdownListener` that records the last tapped image.
private actor RecordingMarkdownListener: MarkdownListener {

  private var tappedImage: MarkdownImage?
  private var continuation: CheckedContinuation<MarkdownImage, Never>?

  func nextImageTap() async -> MarkdownImage {
    if let tappedImage {
      return tappedImage
    }
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
  }

  nonisolated func onRender(markdown: RenderableDocument) async {}
  nonisolated func onTableCopyTap(content: String) async {}
  nonisolated func onTableDownloadTap(content: String) async {}
  nonisolated func onContextMenuAppear(id: String, selectedContent: String) async {}
  nonisolated func onContextMenuTap(id: String, selectedContent: String) async {}

  func onImageTap(image: MarkdownImage) async {
    if let continuation {
      self.continuation = nil
      continuation.resume(returning: image)
    } else {
      tappedImage = image
    }
  }
}
