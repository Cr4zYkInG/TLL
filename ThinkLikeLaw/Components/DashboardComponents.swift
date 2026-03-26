import SwiftUI
import UniformTypeIdentifiers

/**
 * DeadlinesCountdownWidget — A horizontal display of upcoming exam dates
 */
struct DeadlinesCountdownWidget: View {
    let deadlines: [PersistedDeadline]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Exams")
                .font(Theme.Fonts.inter(size: 16, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    let sorted = deadlines.sorted(by: { $0.impactScore > $1.impactScore })
                    ForEach(sorted.prefix(5)) { deadline in
                        DeadlineMiniCard(deadline: deadline)
                            .hapticFeedback(.light)
                    }
                    
                    if deadlines.count > 3 {
                        NavigationLink(destination: DeadlinesView()) {
                            VStack {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(Theme.Colors.accent)
                                Text("View All")
                                    .font(Theme.Fonts.inter(size: 12, weight: .bold))
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            .frame(width: 100, height: 120)
                            .glassCard()
                        }
                        .hapticFeedback(.light)
                    }
                }
            }
        }
    }
}

struct DeadlineMiniCard: View {
    let deadline: PersistedDeadline
    
    var daysRemaining: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: deadline.date).day ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(deadline.title)
                    .font(Theme.Fonts.inter(size: 14, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
                
                Circle()
                    .fill((deadline.weight ?? 0.0) >= 30 ? .red : priorityColor)
                    .frame(width: 8, height: 8)
                
                if (deadline.weight ?? 0.0) >= 30 {
                    Text("IMPACT")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.red)
                }
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(max(0, daysRemaining))")
                    .font(Theme.Fonts.inter(size: 28, weight: .black))
                    .foregroundColor(daysRemaining < 7 ? .red : Theme.Colors.textPrimary)
                
                Text("DAYS")
                    .font(Theme.Fonts.inter(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Text(deadline.date.formatted(date: .abbreviated, time: .omitted))
                .font(Theme.Fonts.inter(size: 11))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(width: 160)
        .padding(Theme.Spacing.medium)
        .glassCard()
        .shadow(color: Theme.Shadows.soft, radius: 8, y: 4)
        .contextMenu {
            Button {
                Task {
                    try? await CalendarService.shared.addDeadlineEvent(for: deadline)
                }
            } label: {
                Label("Add to Calendar", systemImage: "calendar.badge.plus")
            }
        }
    }
    
    private var priorityColor: Color {
        switch deadline.priority ?? 1 {
        case 0: return .blue
        case 2: return .red
        default: return .orange
        }
    }
}

struct ModuleCard: View {
    let module: LawModule
    let deadlines: [PersistedDeadline]
    
    var closestDeadline: PersistedDeadline? {
        deadlines.filter { $0.moduleId == module.id && $0.date >= Date() }
            .min(by: { $0.date < $1.date })
    }
    
    var daysRemaining: Int? {
        if let deadline = closestDeadline {
            return Calendar.current.dateComponents([.day], from: Date(), to: deadline.date).day
        }
        return nil
    }
    
    var progressFraction: Double {
        guard let deadline = closestDeadline else { return 0 }
        let totalDays = Calendar.current.dateComponents([.day], from: deadline.createdAt ?? Date(), to: deadline.date).day ?? 1
        let elapsed = Calendar.current.dateComponents([.day], from: deadline.createdAt ?? Date(), to: Date()).day ?? 0
        
        if totalDays <= 0 { return 1.0 }
        let fraction = Double(elapsed) / Double(totalDays)
        return min(max(fraction, 0), 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Icon & Deadline
            HStack {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: module.sfSymbol)
                        .font(.system(size: 20))
                        .foregroundColor(Theme.Colors.accent)
                }
                
                Spacer()
                
                if let days = daysRemaining {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(max(0, days)) Days")
                            .font(Theme.Fonts.inter(size: 14, weight: .bold))
                            .foregroundColor(days < 7 ? .red : Theme.Colors.textPrimary)
                        Text("Left")
                            .font(Theme.Fonts.inter(size: 10, weight: .semibold))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(module.name)
                    .font(Theme.Fonts.inter(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                
                Text(module.description)
                    .font(Theme.Fonts.inter(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Predictive Insight
                HStack(spacing: 4) {
                    let insight = predictiveInsight()
                    Image(systemName: insight.icon)
                        .font(.system(size: 10))
                    Text(insight.text)
                        .font(.system(size: 10, weight: .black))
                }
                .foregroundColor(predictiveInsight().color)
                .padding(.top, 2)
            }
            
            if closestDeadline != nil {
                // Sleek progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.glassBorder)
                            .frame(height: 4)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Theme.Colors.accent)
                            .frame(width: max(0, geo.size.width * CGFloat(progressFraction)), height: 4)
                    }
                }
                .frame(height: 4)
            }
        }
        .padding(Theme.Spacing.medium)
        .glassCard()
        .shadow(color: Theme.Shadows.soft, radius: 10, y: 5)
    }
    
    private func predictiveInsight() -> (text: String, icon: String, color: Color) {
        let retention = module.averageRetention
        
        if retention < 70 {
            return ("RETENTION DROPPING", "exclamationmark.arrow.triangle.2.circlepath", .red)
        } else if daysRemaining ?? 100 < 14 {
            return ("INTENSE FOCUS SUGGESTED", "bolt.fill", .orange)
        } else if retention < 85 {
            return ("REVIEW RECOMMENDED", "clock.arrow.2.circlepath", Theme.Colors.accent)
        } else {
            return ("KNOWLEDGE SECURED", "checkmark.seal.fill", .green)
        }
    }
}

struct FolderCard: View {
    let module: PersistedModule
    
    var flashcardDueCount: Int {
        module.flashcardSets.reduce(0) { sum, set in
            sum + set.cards.filter { $0.nextReviewDate <= Date().addingTimeInterval(60) }.count
        }
    }
    
    var flashcardTotalCount: Int {
        module.flashcardSets.reduce(0) { $0 + $1.cards.count }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 80))
                        .foregroundColor(Theme.Colors.accent.opacity(0.2))
                    
                    Image(systemName: module.sfSymbol)
                        .font(.system(size: 24))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(8)
                        .background(Theme.Colors.bg)
                        .clipShape(Circle())
                        .offset(x: -10, y: -10)
                }
                
                // Due Badge
                if flashcardDueCount > 0 {
                    Text("\(flashcardDueCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .offset(x: 5, y: -5)
                        .shadow(color: .orange.opacity(0.3), radius: 4, y: 2)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(module.name)
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                        Text("\(module.notes.count)")
                    }
                    .foregroundColor(Theme.Colors.textSecondary)
                    
                    if flashcardTotalCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "rectangle.stack")
                            Text("\(flashcardTotalCount)")
                        }
                        .foregroundColor(Theme.Colors.accent.opacity(0.7))
                    }
                }
                .font(Theme.Fonts.inter(size: 11, weight: .semibold))
            }
        }
        .padding(Theme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .shadow(color: Theme.Shadows.soft, radius: 8, y: 4)
    }
}


// MARK: - Drag & Drop Delegate (Shared across Dashboard and Modules List)
struct ModuleDropDelegate: DropDelegate {
    let item: PersistedModule
    let items: [PersistedModule]
    @Binding var draggingItem: PersistedModule?
    let onMove: (PersistedModule, PersistedModule) -> Void
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem,
              dragging.id != item.id else { return }
        
        onMove(dragging, item)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

/**
 * EliteToolCard — Represents a premium judicial tool in the Dashboard Lab.
 */
struct EliteToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let destination: AnyView
    
    @AppStorage("aiPlusEnabled") var aiPlusEnabled: Bool = false
    
    var body: some View {
        NavigationLink(destination: destination) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(subtitle)
                        .font(Theme.Fonts.inter(size: 10))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineLimit(1)
                }
                
                if !aiPlusEnabled {
                    HStack(spacing: 4) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                        Text("Plus Feature")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(Theme.Colors.accent)
                    .padding(.top, 4)
                } else {
                    Spacer().frame(height: 18)
                }
            }
            .frame(width: 140, height: 160)
            .padding()
            .background(Theme.Colors.surface)
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
            .glassCard()
        }
        .buttonStyle(.plain)
    }
}
