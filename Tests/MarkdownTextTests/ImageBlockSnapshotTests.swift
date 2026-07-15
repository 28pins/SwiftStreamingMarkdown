//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import SwiftUI
@testable import SwiftStreamingMarkdown
import XCTest

/// Snapshot and resolution coverage for block-level images parsed from Markdown
/// and resolved through a `MarkdownListener` fallback when the resource is
/// absent from the app's main bundle.
@MainActor
final class ImageBlockSnapshotTests: SnapshotTestCase {

  private let bundledImageName = "sample-landscape"
  private let bundledImageExt = "png"

  /// Renders the bundled test image through the library's image presentation
  /// (`Image(mdImage:)` + `.resizable().scaledToFit()`), matching how a resolved
  /// block image is displayed. Deterministic: the image is loaded synchronously
  /// from the test bundle, so it does not depend on the async loading path.
  func test_bundled_image_renders() throws {
    let image = try loadBundledImage()

    let view = CanvasView {
      Image(mdImage: image)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: .infinity, alignment: .center)
    }

    assert(view)
  }

  /// Parses Markdown containing a bundled-resource image and resolves it end to
  /// end through the listener fallback. The resource lives only in the test
  /// bundle (absent from the main bundle), so resolution must go through the
  /// listener. Deterministic — it validates the pipeline and resolution without
  /// relying on the async view rendering path.
  func test_parsed_bundled_image_resolves_via_listener() async throws {
    XCTAssertNil(
      Bundle.main.url(forResource: bundledImageName, withExtension: bundledImageExt),
      "Precondition: the test image must not be present in the main bundle"
    )

    let text = """
    This is an image.

    ![Landscape](\(bundledImageName).\(bundledImageExt))
    """
    let config = MarkdownRenderConfig(
      imageConfig: ImageConfig(enabled: true, allowedImageTypes: [.bundledResource])
    )
    let parser = MarkdownParserImpl()
    let document = await parser.parse(
      text: text,
      option: .init(speculativeRewrite: false, imageSupport: true)
    ).document
    let renderables = await RenderableDocument(document: document, config: config).renderables

    let imageData = renderables.compactMap { renderable -> ImageData? in
      if case .image(_, let data) = renderable { return data }
      return nil
    }.first
    let data = try XCTUnwrap(imageData, "Expected the parsed document to contain an image block")
    XCTAssertEqual(data.source, .bundledResource(fileName: bundledImageName, ext: bundledImageExt))

    let controller = MarkdownController(listener: BundleResourceListener(bundle: .module))
    let image = await data.makeMarkdownImage(controller: controller)
    let payload = try XCTUnwrap(image)
    guard case .bundledResource(let bytes) = payload.source else {
      return XCTFail("Expected a bundled-resource payload resolved via the listener")
    }
    XCTAssertFalse(bytes.isEmpty)
  }

  /// Without a resolving listener, a bundled resource missing from the main
  /// bundle stays unresolved.
  func test_missing_bundled_resource_is_nil_without_listener() async throws {
    let data = ImageData(
      source: .bundledResource(fileName: bundledImageName, ext: bundledImageExt),
      alt: "Landscape"
    )

    let payload = await data.makeMarkdownImage(controller: nil)
    XCTAssertNil(payload)
  }

  /// Loads the bundled test image synchronously from the test bundle, reporting
  /// a normal XCTest failure at the call site if it is missing or undecodable.
  private func loadBundledImage(
    file: StaticString = #filePath,
    line: UInt = #line
  ) throws -> MDImage {
    let url = try XCTUnwrap(
      Bundle.module.url(forResource: bundledImageName, withExtension: bundledImageExt),
      "Missing bundled test image: \(bundledImageName).\(bundledImageExt)",
      file: file,
      line: line
    )
    let data = try Data(contentsOf: url)
    return try XCTUnwrap(
      MDImage(data: data),
      "Could not decode bundled test image: \(bundledImageName).\(bundledImageExt)",
      file: file,
      line: line
    )
  }
}

/// Minimal `MarkdownListener` that resolves bundled resources from a specific
/// bundle, used to stand in for a dependency package or framework bundle.
private final class BundleResourceListener: MarkdownListener {
  let bundle: Bundle

  init(bundle: Bundle) {
    self.bundle = bundle
  }

  func onRender(markdown: RenderableDocument) async {}
  func onTableCopyTap(content: String) async {}
  func onTableDownloadTap(content: String) async {}
  func onContextMenuAppear(id: String, selectedContent: String) async {}
  func onContextMenuTap(id: String, selectedContent: String) async {}
  func onImageTap(image: MarkdownImage) async {}

  func resolveBundledResource(fileName: String, ext: String?) -> URL? {
    bundle.url(forResource: fileName, withExtension: ext)
  }
}
