//
//  MermaidBlockView.swift
//  SwiftStreamingMarkdown
//
//  Created by Sam Clark on 8/11/26.
//

import SwiftUI
import BeautifulMermaid

struct MermaidBlockView: View {
	@Environment(\.markdownConfig) var config: MarkdownRenderConfig
	@Environment(\.colorScheme) var colorScheme
	@State var code: String

	var body: some View {
		MermaidDiagramView(
			source: code,
			theme: config.mermaidConfig.theme.diagramTheme(for: colorScheme)
		)
		.clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
	}
}
