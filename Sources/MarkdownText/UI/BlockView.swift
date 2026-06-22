//
//  Copyright (c) Microsoft Corporation. All rights reserved.
//  Licensed under the MIT License. See LICENSE in the project root for license information.
//

import Foundation
import SwiftUI

struct BlockView: View {

  let renderables: [MarkdownRenderable]

  init(renderables: [MarkdownRenderable]) {
    self.renderables = renderables
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 30) {
      ForEach(renderables) { renderable in
        SingleBlockView(renderable: renderable)
      }
    }
  }
}

struct SingleBlockView: View {

  @Environment(\.markdownConfig) var config: MarkdownRenderConfig

  let renderable: MarkdownRenderable

  init(renderable: MarkdownRenderable) {
    self.renderable = renderable
  }

  var body: some View {
    Group {
      switch renderable {
      case .heading(_, _, let contents):
        HStack(spacing: 0) {
          #if os(macOS)
          ParagraphViewMac(contents: contents)
            .transition(.opacity)
            .accessibilityAddTraits(.isHeader)
          #else
          ParagraphView(contents: contents)
            .transition(.opacity)
            .accessibilityAddTraits(.isHeader)
          #endif
          Spacer()
        }
      case .paragraph(_, let contents):
        HStack(spacing: 0) {
          #if os(macOS)
          ParagraphViewMac(contents: contents, lineSpacing: 5)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity)
          #else
          ParagraphView(contents: contents, lineSpacing: 5)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity)
          #endif
          Spacer()
        }
      case .latex(_, let latexString):
        #if os(macOS)
        // TODO: Add macOS BlockMathView equivalent
        Text(latexString)
          .font(.system(.body, design: .monospaced))
        #else
        ScrollView(.horizontal) {
          HStack(spacing: 0) {
            BlockMathView(latex: latexString, color: Color(config.paragraphStyle.textColor))
            Spacer()
          }
        }.scrollIndicators(.hidden)
        #endif
      case .orderedList(_, let items):
        OrderedListView(items: items)
      case .unorderedList(_, let items, let nestedLevel):
        UnorderedListView(items: items, nestedLevel: nestedLevel)
      case .codeBlock(_, let language, let code):
        CodeBlockView(language: language ?? "",
                      code: code)
      case .thematicBreak:
        ThematicBreakView()
      case .table(_, let headers, let rows, let rawMarkdown):
        TableView(headings: headers,
                  rows: rows,
                  rawMarkdown: rawMarkdown)
      case .blockQuote(_, let item):
        BlockQuoteView(item: item)
      }
    }
  }
}
