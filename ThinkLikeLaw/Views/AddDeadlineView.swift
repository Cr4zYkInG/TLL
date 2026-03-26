import SwiftUI
import SwiftData

struct AddDeadlineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query var modules: [PersistedModule]
    
    @State private var title = ""
    @State private var date = Date()
    @State private var weight = 50.0
    @State private var selectedModule: PersistedModule?
    @State private var isNotificationActive = true
    @State private var isSaving = false

    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.bg.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Exam Title (e.g. Contract Law Final)", text: $title)
                            .font(Theme.Fonts.inter(size: 16))
                    } header: {
                        Text("ESSENTIALS")
                            .font(.system(size: 10, weight: .bold))
                    }
                    
                    Section {
                        DatePicker("Date & Time", selection: $date)
                            .font(Theme.Fonts.inter(size: 16))
                        
                        Picker("Module", selection: $selectedModule) {
                            Text("No Module").tag(nil as PersistedModule?)
                            ForEach(modules) { module in
                                HStack {
                                    Image(systemName: module.icon)
                                    Text(module.name)
                                }.tag(module as PersistedModule?)
                            }
                        }
                    } header: {
                        Text("CATEGORIZATION")
                            .font(.system(size: 10, weight: .bold))
                    }
                    
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Weighted Marks")
                                Spacer()
                                Text("\(Int(weight))%")
                                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                                    .foregroundColor(Theme.Colors.accent)
                            }
                            Slider(value: $weight, in: 0...100, step: 5)
                                .accentColor(Theme.Colors.accent)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("IMPACT")
                            .font(.system(size: 10, weight: .bold))
                    }
                    
                    Section {
                        Toggle("Live Notifications", isOn: $isNotificationActive)
                            .font(Theme.Fonts.inter(size: 16))
                    } header: {
                        Text("ALERTS")
                            .font(.system(size: 10, weight: .bold))
                    } footer: {
                        Text("You will receive a notification 24 hours before the deadline.")
                            .font(.system(size: 10))
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveDeadline()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Secure")
                        }
                    }
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveDeadline() {
        guard !isSaving else { return }
        isSaving = true
        
        let deadline = PersistedDeadline(
            title: title,
            date: date,
            moduleId: selectedModule?.id,
            moduleName: selectedModule?.name,
            moduleColor: "0000FF", // Placeholder for now
            weight: weight,
            isNotificationActive: isNotificationActive
        )
        modelContext.insert(deadline)
        
        if isNotificationActive {
            NotificationManager.shared.scheduleDeadlineNotification(for: deadline)
        }
        
        // Push to cloud immediately
        let id = deadline.id
        let t = title
        let d = date
        let mid = selectedModule?.id
        let mname = selectedModule?.name
        let w = weight
        let notify = isNotificationActive
        
        Task {
            do {
                try await SupabaseManager.shared.upsertDeadline(
                    id: id,
                    title: t,
                    date: d,
                    moduleId: mid,
                    moduleName: mname,
                    moduleColor: "0000FF",
                    weight: w,
                    priority: 1,
                    isNotificationActive: notify,
                    isArchived: false
                )
            } catch {
                print("Error pushing deadline to cloud: \(error)")
            }
            await MainActor.run {
                dismiss()
            }
        }
    }
}
