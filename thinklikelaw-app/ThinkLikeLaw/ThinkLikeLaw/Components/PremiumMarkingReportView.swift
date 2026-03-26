import SwiftUI

/**
 * PremiumMarkingReportView — A high-end, visual report for AI marking.
 * Used for both Essay Marking and Exam Simulation Feedback.
 */
struct PremiumMarkingReportView: View {
    let reportText: String
    let examBoard: String?
    
    // Parsed Metrics
    private var grade: String {
        // Simple parser to find "Grade: [X]" or "Grade: X" or "Result: X"
        let patterns = [
            "Grade:\\s*\\[([A-F][+-]?)\\]",
            "Grade:\\s*([A-F][+-]?)",
            "Result:\\s*([A-F][+-]?)",
            "Mark:\\s*([A-F][+-]?)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               let match = regex.firstMatch(in: reportText, options: [], range: NSRange(reportText.startIndex..., in: reportText)) {
                return (reportText as NSString).substring(with: match.range(at: 1)).uppercased()
            }
        }
        return "B" // Fallback
    }
    
    private var percentage: CGFloat {
        switch grade {
        case "A*": return 0.95
        case "A": return 0.85
        case "B": return 0.70
        case "C": return 0.55
        case "D": return 0.40
        default: return 0.25
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // 1. Grade Gauge
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.accent.opacity(0.1), lineWidth: 12)
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .trim(from: 0, to: percentage)
                        .stroke(
                            LinearGradient(
                                colors: [Theme.Colors.accent, Theme.Colors.accent.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                    
                    VStack(spacing: 2) {
                        Text(grade)
                            .font(Theme.Fonts.outfit(size: 48, weight: .bold))
                            .foregroundColor(Theme.Colors.textPrimary)
                        
                        Text("Predicted Grade")
                            .font(Theme.Fonts.inter(size: 10, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                            .textCase(.uppercase)
                    }
                }
                .padding(.top, 10)
                
                if let board = examBoard {
                    Text("Calibrated for \(board)")
                        .font(Theme.Fonts.inter(size: 12))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .glassCard()
            
            // 2. Feedback Content
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(Theme.Colors.accent)
                    Text("Scholar's Feedback")
                        .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                    Spacer()
                }
                
                MarkdownView(content: reportText)
                    .font(Theme.Fonts.inter(size: 15))
                    .foregroundColor(Theme.Colors.textPrimary.opacity(0.9))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .padding(.horizontal)
    }
}

// Simple Markdown helper if not already globally available
struct MarkdownView: View {
    let content: String
    var body: some View {
        // In a real app, use a proper Markdown library or SwiftUI's AttributedString
        // For this demo, we use Text(LocalizedStringKey)
        Text(LocalizedStringKey(content))
    }
}
