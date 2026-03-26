import SwiftUI
import SwiftData

struct DeadlinesView: View {
    @Query(sort: \PersistedDeadline.date) var deadlines: [PersistedDeadline]
    @State private var showingAddDeadline = false
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    // Premium Header
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("The Final Gantry")
                                .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                            Text("Strategic management of your academic milestones.")
                                .font(Theme.Fonts.playfair(size: 16))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        Spacer()
                        Button {
                            showingAddDeadline = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(Theme.Colors.onAccent)
                                .frame(width: 44, height: 44)
                                .background(Theme.Colors.accent)
                                .clipShape(Circle())
                                .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                    }
                    .padding(.top, Theme.isPhone ? 20 : 40)
                    
                    if deadlines.isEmpty {
                        VStack(spacing: 24) {
                            EmptyDeadlineCard(
                                title: "Clear Skies",
                                subtitle: "No upcoming exams or deadlines secured. Tap the '+' to add one."
                            )
                        }
                    } else {
                        // High Impact Deadlines (Impacting > 30%)
                        let critical = deadlines.filter { ($0.weight ?? 0.0) >= 30 && !($0.isArchived ?? false) }
                        if !critical.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                HStack {
                                    Text("CRITICAL IMPACT")
                                        .font(.system(size: 10, weight: .black))
                                        .foregroundColor(.red)
                                    Spacer()
                                    Text("\(critical.count) ACTIVE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Theme.Colors.textSecondary)
                                }
                                
                                ForEach(critical) { deadline in
                                    DeadlineProgressCard(deadline: deadline)
                                }
                            }
                        }
                        
                        // Rest of the Deadlines
                        let others = deadlines.filter { ($0.weight ?? 0.0) < 30 && !($0.isArchived ?? false) }
                        if !others.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("UPCOMING MILESTONES")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(Theme.Colors.textSecondary)
                                
                                VStack(spacing: 16) {
                                    ForEach(others) { deadline in
                                        DeadlineRow(deadline: deadline)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(Theme.isPhone ? Theme.Spacing.medium : Theme.Spacing.huge)
            }
        }
        .sheet(isPresented: $showingAddDeadline) {
            AddDeadlineView()
        }
        .onAppear {
            NotificationManager.shared.requestPermissions()
        }
    }
}

struct DeadlineProgressCard: View {
    let deadline: PersistedDeadline
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(deadline.moduleName ?? "Core Module")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(Theme.Colors.accent)
                    Text(deadline.title)
                        .font(Theme.Fonts.outfit(size: 20, weight: .bold))
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Theme.Colors.accent.opacity(0.1), lineWidth: 4)
                        .frame(width: 44, height: 44)
                    Circle()
                        .trim(from: 0, to: CGFloat((deadline.weight ?? 0.0) / 100))
                        .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(deadline.weight ?? 0.0))")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let now = context.date
                let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: deadline.date)
                let days = diff.day ?? 0
                let hours = diff.hour ?? 0
                let minutes = diff.minute ?? 0
                let seconds = diff.second ?? 0
                let totalSeconds = Int(deadline.date.timeIntervalSince(now))
                
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        if totalSeconds <= 0 {
                            Text("EXPIRED")
                                .font(.system(size: 24, weight: .black, design: .monospaced))
                                .foregroundColor(.red)
                        } else {
                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text("\(days)d \(hours)h \(minutes)m")
                                    .font(.system(size: 20, weight: .black, design: .monospaced))
                                Text("\(seconds)s")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundColor(urgencyColor(for: deadline))
                            }
                            .foregroundColor(days < 7 ? .red : Theme.Colors.textPrimary)
                            
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10))
                                Text(suggestedAction(for: deadline))
                                    .font(.system(size: 10, weight: .black))
                            }
                            .foregroundColor(urgencyColor(for: deadline))
                            .padding(.top, 4)
                        }
                        
                        Text("UNTIL SUBMISSION")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: (deadline.isNotificationActive ?? true) ? "bell.fill" : "bell.slash")
                        Text(deadline.date.formatted(date: .abbreviated, time: .omitted))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.bg)
                    .cornerRadius(20)
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                Theme.Colors.surface
                let days = Calendar.current.dateComponents([.day], from: .now, to: deadline.date).day ?? 0
                if days < 7 {
                    LinearGradient(colors: [.red.opacity(0.05), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
                } else if days < 14 {
                    LinearGradient(colors: [.orange.opacity(0.05), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
                } else {
                    LinearGradient(colors: [.green.opacity(0.05), .clear], startPoint: .topTrailing, endPoint: .bottomLeading)
                }
            }
        )
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(urgencyColor(for: deadline).opacity(0.3), lineWidth: 1)
        )
        .shadow(color: urgencyColor(for: deadline).opacity(0.15), radius: 15, x: 0, y: 10)
        .contextMenu {
            Button {
                addCalendarEvent()
            } label: {
                Label("Add to Calendar", systemImage: "calendar.badge.plus")
            }
            
            Button(role: .destructive) {
                deleteDeadline()
            } label: {
                Label("Delete Deadline", systemImage: "trash")
            }
        }
    }
    
    private func addCalendarEvent() {
        Task {
            try? await CalendarService.shared.addDeadlineEvent(for: deadline)
        }
    }
    
    private func urgencyColor(for deadline: PersistedDeadline) -> Color {
        let days = Calendar.current.dateComponents([.day], from: .now, to: deadline.date).day ?? 0
        if days < 7 { return .red }
        if days < 14 { return .orange }
        return Theme.Colors.accent
    }
    
    private func suggestedAction(for deadline: PersistedDeadline) -> String {
        let days = Calendar.current.dateComponents([.day], from: .now, to: deadline.date).day ?? 0
        if days < 0 { return "AUDIT SUBMISSION" }
        if days < 3 { return "FINAL POLISH & OSCOLA AUDIT" }
        if days < 7 { return "COMPLETE DRAFTING" }
        if days < 14 { return "STRUCTURE & IRAC ANALYSIS" }
        return "COMMENCE RESEARCH"
    }
    
    @Environment(\.modelContext) private var modelContext
    
    private func deleteDeadline() {
        let id = deadline.id
        deadline.isDeleted = true
        try? modelContext.save()
        
        Task {
            try? await SupabaseManager.shared.upsertDeadline(
                id: id,
                title: deadline.title,
                date: deadline.date,
                moduleId: deadline.moduleId,
                moduleName: deadline.moduleName,
                moduleColor: deadline.moduleColor,
                weight: deadline.weight ?? 0.0,
                priority: deadline.priority ?? 1,
                isNotificationActive: deadline.isNotificationActive ?? true,
                isArchived: deadline.isArchived ?? false,
                isDeleted: true
            )
        }
    }
}

struct DeadlineRow: View {
    let deadline: PersistedDeadline
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.Colors.accent.opacity(0.1))
                    .frame(width: 48, height: 48)
                Image(systemName: "timer")
                    .foregroundColor(Theme.Colors.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(deadline.title)
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                Text(deadline.moduleName ?? "Standard Milestone")
                    .font(Theme.Fonts.inter(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
            
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let now = context.date
                let diff = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: now, to: deadline.date)
                let days = diff.day ?? 0
                let totalSeconds = Int(deadline.date.timeIntervalSince(now))

                VStack(alignment: .trailing, spacing: 4) {
                    if totalSeconds <= 0 {
                        Text("EXPIRED")
                            .font(Theme.Fonts.inter(size: 12, weight: .black))
                            .foregroundColor(.red)
                    } else {
                        Text("\(days)d \(diff.hour ?? 0)h")
                            .font(Theme.Fonts.outfit(size: 16, weight: .black))
                            .foregroundColor(days < 14 ? .orange : Theme.Colors.textPrimary)
                    }
                    Text("REMAINING")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .padding(16)
        .background(Theme.Colors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
        .contextMenu {
            Button {
                addCalendarEvent()
            } label: {
                Label("Add to Calendar", systemImage: "calendar.badge.plus")
            }
            
            Button(role: .destructive) {
                deleteDeadline()
            } label: {
                Label("Delete Deadline", systemImage: "trash")
            }
        }
    }
    
    private func addCalendarEvent() {
        Task {
            try? await CalendarService.shared.addDeadlineEvent(for: deadline)
        }
    }
    
    @Environment(\.modelContext) private var modelContext
    
    private func deleteDeadline() {
        let id = deadline.id
        deadline.isDeleted = true
        try? modelContext.save()
        
        Task {
            try? await SupabaseManager.shared.upsertDeadline(
                id: id,
                title: deadline.title,
                date: deadline.date,
                moduleId: deadline.moduleId,
                moduleName: deadline.moduleName,
                moduleColor: deadline.moduleColor,
                weight: deadline.weight ?? 0.0,
                priority: deadline.priority ?? 1,
                isNotificationActive: deadline.isNotificationActive ?? true,
                isArchived: deadline.isArchived ?? false,
                isDeleted: true
            )
        }
    }
}

struct EmptyDeadlineCard: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 32))
                .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
            Text(title)
                .font(Theme.Fonts.outfit(size: 16, weight: .bold))
            Text(subtitle)
                .font(Theme.Fonts.inter(size: 14))
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Theme.Colors.surface.opacity(0.5))
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1, antialiased: true))
    }
}
