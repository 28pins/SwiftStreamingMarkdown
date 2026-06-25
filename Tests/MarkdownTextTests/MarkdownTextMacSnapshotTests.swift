//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//
#if canImport(AppKit)
import Markdown
import SnapshotTesting
@testable import SwiftStreamingMarkdown
import SwiftUI
import XCTest

@MainActor
final class MarkdownTextMacSnapshotTests: SnapshotTestCase {

  let parser: MarkdownParser = MarkdownParserImpl()

  func testMarkdownLists_macOS() async throws {
    let text = """
     I found some resources that can help you compare gyms in your neighborhood. Here's a brief overview:

    1. **The Ultimate Gym Guide** provides a comprehensive database of gyms where you can compare amenities, locations with pools, saunas, childcare, and more.
    2. **Best Gyms Near Me** on Yelp lists gyms with a variety of classes, equipment, and amenities, from budget-friendly options to high-end gyms with all the bells and whistles.

    You can visit these sites to get detailed information on **membership prices** and **amenities** for each gym. Remember to consider what's most important for your fitness routine when making your decision!

    Here are some other lists:
    - **The Ultimate Gym Guide** provides a comprehensive database of gyms where you can compare amenities, locations with pools, saunas, childcare, and more.
    - **Best Gyms Near Me** on Yelp lists gyms with a variety of classes, equipment, and amenities, from budget-friendly options to high-end gyms with all the bells and whistles.

    """

    let document = await parser.parse(text: text)
    let renderables = await RenderableDocument(document: document, config: .default)
    let view = CanvasView {
      DocumentView(renderableDocument: renderables, config: .init()).padding(.horizontal, 24)
    }
    assert(view)
  }

  func testMarkdownWithCodeBlock_macOS() async throws {
    let text = """
    Here's an example:

    ```swift
    func greet(name: String) -> String {
        return "Hello, \\(name)!"
    }

    let message = greet(name: "World")
    print(message)
    ```

    Pretty neat, right?
    """

    let document = await parser.parse(text: text)
    let renderables = await RenderableDocument(document: document, config: .default)
    let view = CanvasView {
      DocumentView(renderableDocument: renderables, config: .init()).padding(.horizontal, 24)
    }
    assert(view)
  }

  func testMarkdownWithTable_macOS() async throws {
    let text = """
    Here's a comparison:

    | Feature | iOS | macOS |
    |---------|-----|-------|
    | UIKit | ✅ | ❌ |
    | AppKit | ❌ | ✅ |
    | SwiftUI | ✅ | ✅ |

    Both platforms support SwiftUI.
    """

    let document = await parser.parse(text: text)
    let renderables = await RenderableDocument(document: document, config: .default)
    let view = CanvasView {
      DocumentView(renderableDocument: renderables, config: .init()).padding(.horizontal, 24)
    }
    assert(view)
  }

}
#endif
