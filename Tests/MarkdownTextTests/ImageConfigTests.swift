//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

@testable import SwiftStreamingMarkdown
import XCTest

final class ImageConfigTests: XCTestCase {

  private func url(_ string: String) -> URL {
    guard let url = URL(string: string) else {
      fatalError("Invalid test URL: \(string)")
    }
    return url
  }

  func test_disabled_config_allows_nothing() {
    let config = ImageConfig(enabled: false, allowedImageTypes: [.remote(allowedDomains: [])])
    XCTAssertFalse(config.allowsImage(from: url("https://example.com/a.png")))
  }

  func test_enabled_without_allowed_types_allows_nothing() {
    let config = ImageConfig(enabled: true)
    XCTAssertFalse(config.allowsImage(from: url("https://example.com/a.png")))
  }

  func test_nil_url_is_not_allowed() {
    let config = ImageConfig(enabled: true, allowedImageTypes: [.remote(allowedDomains: [])])
    XCTAssertFalse(config.allowsImage(from: nil))
  }

  func test_empty_allowed_domains_permits_any_host() {
    let config = ImageConfig(enabled: true, allowedImageTypes: [.remote(allowedDomains: [])])
    XCTAssertTrue(config.allowsImage(from: url("https://anything.example/a.png")))
    XCTAssertTrue(config.allowsImage(from: url("http://anything.example/a.png")))
  }

  func test_allowed_domain_matches_exact_and_subdomains() {
    let config = ImageConfig(
      enabled: true,
      allowedImageTypes: [.remote(allowedDomains: ["markdownguide.org"])]
    )
    XCTAssertTrue(config.allowsImage(from: url("https://markdownguide.org/a.png")))
    XCTAssertTrue(config.allowsImage(from: url("https://www.markdownguide.org/a.png")))
    XCTAssertFalse(config.allowsImage(from: url("https://example.com/a.png")))
    XCTAssertFalse(config.allowsImage(from: url("https://notmarkdownguide.org/a.png")))
  }

  func test_domain_matching_is_case_insensitive() {
    let config = ImageConfig(
      enabled: true,
      allowedImageTypes: [.remote(allowedDomains: ["Markdownguide.ORG"])]
    )
    XCTAssertTrue(config.allowsImage(from: url("https://WWW.MarkdownGuide.org/a.png")))
  }

  func test_non_http_schemes_are_not_allowed() {
    let config = ImageConfig(enabled: true, allowedImageTypes: [.remote(allowedDomains: [])])
    XCTAssertFalse(config.allowsImage(from: url("file:///tmp/a.png")))
    XCTAssertFalse(config.allowsImage(from: url("ftp://example.com/a.png")))
  }
}
