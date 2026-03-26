import SwiftUI

/**
 * NoteContentView — Intelligently chooses between Markdown and HTML rendering.
 * Website notes typically sync as HTML, while app-generated notes are Markdown.
 */
struct NoteContentView: View {
    let content: String
    let paperColor: String
    
    var body: some View {
        if isHTML(content) {
            HTMLView(htmlContent: content, paperColor: paperColor)
        } else {
            MarkdownText(text: content)
        }
    }
    
    private func isHTML(_ str: String) -> Bool {
        let htmlTriggers = ["<p", "<h3", "<div", "<span", "<br", "style="]
        return htmlTriggers.contains { str.lowercased().contains($0) }
    }
}
