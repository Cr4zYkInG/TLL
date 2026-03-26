import SwiftUI

struct LeaderboardView: View {
    @State private var timeRankings: [LeaderboardEntry] = []
    @State private var streakRankings: [LeaderboardEntry] = []
    @State private var selectedTab = 0
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            VStack {
                // Tab Selection
                Picker("Category", selection: $selectedTab) {
                    Text("Top Minds").tag(0)
                    Text("Longest Streaks").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if (selectedTab == 0 ? timeRankings : streakRankings).isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "trophy")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.3))
                        Text("No rankings available yet.")
                            .font(Theme.Fonts.outfit(size: 18, weight: .semibold))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(Array((selectedTab == 0 ? timeRankings : streakRankings).enumerated()), id: \.element.id) { index, entry in
                            LeaderboardRow(entry: entry, rank: index + 1)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
        }
        .navigationTitle("Leaderboard")
        .onAppear {
            loadData()
        }
    }
    
    func loadData() {
        isLoading = true
        Task {
            do {
                let raw = try await SupabaseManager.shared.fetchLeaderboard()
                await MainActor.run {
                    self.timeRankings = raw.map { r in
                        let profileRaw = r["profiles"]
                        let profile = (profileRaw as? [String: Any]) ?? (profileRaw as? [[String: Any]])?.first ?? [:]
                        
                        let totalXP = r["total_xp"] as? Int ?? 0
                        return LeaderboardEntry(
                            id: UUID().uuidString,
                            name: "\(profile["first_name"] as? String ?? "Counsel") \(profile["last_name"] as? String ?? "")",
                            score: "\(totalXP) XP",
                            avatar: profile["avatar_url"] as? String ?? ""
                        )
                    }
                    
                    self.streakRankings = raw.sorted { (a, b) -> Bool in
                        (a["streak"] as? Int ?? 0) > (b["streak"] as? Int ?? 0)
                    }.map { r in
                        let profileRaw = r["profiles"]
                        let profile = (profileRaw as? [String: Any]) ?? (profileRaw as? [[String: Any]])?.first ?? [:]
                        
                        let streak = r["streak"] as? Int ?? 1
                        return LeaderboardEntry(
                            id: UUID().uuidString,
                            name: "\(profile["first_name"] as? String ?? "Counsel") \(profile["last_name"] as? String ?? "")",
                            score: "\(streak) Days",
                            avatar: profile["avatar_url"] as? String ?? ""
                        )
                    }
                    self.isLoading = false
                }
            } catch {
                print("Leaderboard error: \(error)")
                self.isLoading = false
            }
        }
    }
}

struct LeaderboardEntry: Identifiable {
    let id: String
    let name: String
    let score: String
    let avatar: String
}

struct LeaderboardRow: View {
    let entry: LeaderboardEntry
    let rank: Int
    
    var body: some View {
        HStack(spacing: 16) {
            Text("\(rank)")
                .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                .foregroundColor(rank <= 3 ? (rank == 1 ? Color.yellow : (rank == 2 ? Color.gray : Color.orange)) : Theme.Colors.textSecondary)
                .frame(width: 30)
            
            Circle()
                .fill(LinearGradient(colors: [Theme.Colors.accent.opacity(0.1), Theme.Colors.accent.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(entry.name.prefix(1))
                        .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("LLB Candidate")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            
            Spacer()
            
            Text(entry.score)
                .font(Theme.Fonts.outfit(size: 16, weight: .black))
                .foregroundColor(Theme.Colors.accent)
        }
        .padding(16)
        .background(
            ZStack {
                Theme.Colors.surface
                if rank == 1 {
                    LinearGradient(colors: [Color.yellow.opacity(0.15), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else if rank == 2 {
                    LinearGradient(colors: [Color.gray.opacity(0.15), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                } else if rank == 3 {
                    LinearGradient(colors: [Color.orange.opacity(0.15), Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        )
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
    }
}
