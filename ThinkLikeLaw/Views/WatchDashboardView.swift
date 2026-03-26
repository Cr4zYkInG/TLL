import SwiftUI

struct WatchDashboardView: View {
    @State private var criticalDeadlines: [WatchDeadline] = [
        WatchDeadline(title: "Contract Exam", daysLeft: 12),
        WatchDeadline(title: "Tort Essay", daysLeft: 5)
    ]
    
    var body: some View {
        NavigationStack {
            List {
                Section("Deadlines") {
                    ForEach(criticalDeadlines) { deadline in
                        VStack(alignment: .leading) {
                            Text(deadline.title)
                                .font(.system(size: 14, weight: .bold))
                            if deadline.daysLeft <= 7 {
                                Text("\(deadline.daysLeft) DAYS LEFT")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(.red)
                            } else {
                                Text("\(deadline.daysLeft) days remaining")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: triggerRecording) {
                        Label("Quick Record", systemImage: "mic.fill")
                            .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle("ThinkLikeLaw")
        }
    }
    
    private func triggerRecording() {
        // Send message to iPhone via ConnectivityManager
        // WatchConnectivityManager.shared.sendMessage(["action": "start_recording"])
    }
}

struct WatchDeadline: Identifiable {
    let id = UUID()
    let title: String
    let daysLeft: Int
}
