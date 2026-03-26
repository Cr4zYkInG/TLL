import SwiftUI
import Combine

/**
 * MarkdownText — A lightweight markdown renderer for ThinkLikeLaw AI outputs.
 * Supports:
 * ### Header (H3 style)
 * **Bold**
 * *Italics*
 */
struct MarkdownText: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseBlocks(text), id: \.id) { block in
                renderBlock(block)
            }
        }
    }
    
    // MARK: - Parser
    
    struct TextBlock: Identifiable {
        let id = UUID()
        let content: String
        let headerLevel: Int // 0 for body, 1 for H1, 2 for H2, 3 for H3
    }
    
    private func parseBlocks(_ input: String) -> [TextBlock] {
        let lines = input.components(separatedBy: .newlines)
        var blocks: [TextBlock] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if trimmed.hasPrefix("###") {
                let content = trimmed.replacingOccurrences(of: "###", with: "").trimmingCharacters(in: .whitespaces)
                blocks.append(TextBlock(content: content, headerLevel: 3))
            } else if trimmed.hasPrefix("##") {
                let content = trimmed.replacingOccurrences(of: "##", with: "").trimmingCharacters(in: .whitespaces)
                blocks.append(TextBlock(content: content, headerLevel: 2))
            } else if trimmed.hasPrefix("#") {
                let content = trimmed.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                blocks.append(TextBlock(content: content, headerLevel: 1))
            } else {
                blocks.append(TextBlock(content: line, headerLevel: 0))
            }
        }
        
        return blocks
    }
    
    // MARK: - Renderer
    
    @ViewBuilder
    private func renderBlock(_ block: TextBlock) -> some View {
        switch block.headerLevel {
        case 1:
            Text(block.content)
                .font(Theme.Fonts.outfit(size: 28, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
        case 2:
            Text(block.content)
                .font(Theme.Fonts.outfit(size: 22, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
        case 3:
            Text(block.content)
                .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text(parseInlineMarkdown(block.content))
                .font(Theme.Fonts.inter(size: 16))
                .lineSpacing(4)
                .foregroundColor(Theme.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    private func parseInlineMarkdown(_ content: String) -> AttributedString {
        do {
            // Using modern AttributedString with markdown support
            // Note: Swift's AttributedString.markdown supports ** and * by default
            var attrString = try AttributedString(markdown: content, options: .init(allowsExtendedAttributes: true, interpretedSyntax: .inlineOnlyPreservingWhitespace))
            
            // Apply theme font to the entire string as it loses it during markdown parsing
            attrString.font = Theme.Fonts.inter(size: 16)
            
            return attrString
        } catch {
            return AttributedString(content)
        }
    }
}

#Preview {
    ScrollView {
        MarkdownText(text: """
        ### Key Principles
        In the case of **Donoghue v Stevenson**, the court established the *Neighbor Principle*.
        
        ### Summary
        1. Duty of care is owed to those likely to be affected.
        2. Breach occurs if standard of care is not met.
        """)
        .padding()
    }
    .background(Theme.Colors.bg)
}
