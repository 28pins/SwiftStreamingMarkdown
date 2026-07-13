//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

@testable import SwiftStreamingMarkdown
import Markdown
import XCTest

@MainActor
final class ImageBlockRenderingTests: XCTestCase {

  private func renderables(
    for text: String,
    imageSupport: Bool
  ) async -> [MarkdownRenderable] {
    let parser = MarkdownParserImpl()
    let config = MarkdownRenderConfig(imageConfig: ImageConfig(enabled: imageSupport))
    let document = await parser.parse(
      text: text,
      option: .init(speculativeRewrite: false, imageSupport: imageSupport)
    ).document
    return await RenderableDocument(document: document, config: config).renderables
  }

  func test_standalone_image_renders_as_paragraph_when_disabled() async {
    let renderables = await renderables(
      for: "![alt](https://example.com/a.png)",
      imageSupport: false
    )

    XCTAssertEqual(renderables.count, 1)
    guard case .paragraph = renderables[0] else {
      return XCTFail("Expected a paragraph when image support is disabled")
    }
  }

  func test_standalone_image_renders_as_image_block_when_enabled() async {
    let renderables = await renderables(
      for: "![alt](https://example.com/a.png)",
      imageSupport: true
    )

    XCTAssertEqual(renderables.count, 1)
    guard case .image(_, let data) = renderables[0] else {
      return XCTFail("Expected an image block when image support is enabled")
    }
    XCTAssertEqual(data.url, URL(string: "https://example.com/a.png"))
    XCTAssertEqual(data.alt, "alt")
  }

  func test_image_mixed_with_text_is_split_into_blocks_when_enabled() async {
    let renderables = await renderables(
      for: "before ![alt](https://example.com/a.png) after",
      imageSupport: true
    )

    XCTAssertEqual(renderables.count, 3)
    guard case .paragraph = renderables[0] else {
      return XCTFail("Expected leading text paragraph")
    }
    guard case .image(_, let data) = renderables[1] else {
      return XCTFail("Expected the middle block to be an image")
    }
    XCTAssertEqual(data.url, URL(string: "https://example.com/a.png"))
    guard case .paragraph = renderables[2] else {
      return XCTFail("Expected trailing text paragraph")
    }
  }
}
