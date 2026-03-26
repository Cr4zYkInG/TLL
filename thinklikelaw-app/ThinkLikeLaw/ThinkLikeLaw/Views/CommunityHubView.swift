import SwiftUI

struct CommunityHubView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selectedTab: String = "Everything"
    @State private var searchText: String = ""
    @State private var items: [[String: Any]] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    let tabs = ["Everything", "Notes", "Flashcard Decks"]
    
    private var isCompact: Bool {
        Theme.isPhone || horizontalSizeClass == .compact
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            VStack(alignment: .leading, spacing: isCompact ? 16 : 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("The Library of Chambers")
                        .font(Theme.Fonts.playfair(size: isCompact ? 28 : 34, weight: .bold))
                    Text("Browse, upvote, and fork high-quality notes and flashcards shared by fellow students.")
                        .font(Theme.Fonts.inter(size: isCompact ? 14 : 16))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                
                // Search & Filter Bar
                if isCompact {
                    VStack(alignment: .leading, spacing: 12) {
                        searchField
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                moduleFilter
                                uniFilter
                            }
                        }
                    }
                } else {
                    HStack(spacing: 12) {
                        searchField
                        moduleFilter
                        uniFilter
                    }
                }
            }
            .padding(isCompact ? 16 : 32)
            
            // Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tabs, id: \.self) { tab in
                        Button(action: { withAnimation(.spring()) { selectedTab = tab } }) {
                            Text(tab)
                                .font(Theme.Fonts.inter(size: 14, weight: .bold))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(selectedTab == tab ? Theme.Colors.accent : Theme.Colors.surface)
                                .foregroundColor(selectedTab == tab ? Theme.Colors.onAccent : Theme.Colors.textSecondary)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(selectedTab == tab ? Color.clear : Theme.Colors.glassBorder, lineWidth: 1)
                                )
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, isCompact ? 16 : 32)
            }
            .padding(.bottom, 24)
            
            // Content Grid
            ScrollView {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Consulting the archives...")
                            .font(Theme.Fonts.inter(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else if filteredItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.minus")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.3))
                        Text("The library is quiet...")
                            .font(Theme.Fonts.playfair(size: 24, weight: .bold))
                        Text("Try broadening your search or be the first to share!")
                            .font(Theme.Fonts.inter(size: 16))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 120)
                } else {
                    let columns: [GridItem] = [
                        GridItem(.adaptive(minimum: isCompact ? 340 : 380), spacing: 24)
                    ]
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(filteredItems.indices, id: \.self) { index in
                            let item = filteredItems[index]
                            CommunityCard(item: item, onFork: { handleFork(item: item) })
                        }
                    }
                    .padding(isCompact ? 16 : 32)
                }
            }
        }
        .onAppear {
            fetchFeed()
        }
    }
    
    // MARK: - Subviews
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.Colors.textSecondary)
            TextField("Search by topic, case name, or user...", text: $searchText)
                .font(Theme.Fonts.inter(size: 15))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.Colors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
    
    private var moduleFilter: some View {
        HStack(spacing: 8) {
            Text("All Modules")
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
        }
        .font(Theme.Fonts.inter(size: 14, weight: .bold))
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.Colors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
    
    private var uniFilter: some View {
        HStack(spacing: 8) {
            Text("All Universities")
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .bold))
        }
        .font(Theme.Fonts.inter(size: 14, weight: .bold))
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Theme.Colors.surface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Theme.Colors.glassBorder, lineWidth: 1))
    }
    
    var filteredItems: [[String: Any]] {
        items.filter { item in
            let type = item["type"] as? String ?? ""
            let matchesTab = selectedTab == "Everything" || 
                           (selectedTab == "Notes" && type == "note") ||
                           (selectedTab == "Flashcard Decks" && type == "flashcard")
            
            let title = item["title"] as? String ?? ""
            let author = item["author_name"] as? String ?? ""
            let matchesSearch = searchText.isEmpty || 
                               title.localizedCaseInsensitiveContains(searchText) ||
                               author.localizedCaseInsensitiveContains(searchText)
            return matchesTab && matchesSearch
        }
    }
    
    func fetchFeed() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetchedItems = try await SupabaseManager.shared.fetchCommunityFeed()
                await MainActor.run {
                    self.items = fetchedItems
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func handleFork(item: [String: Any]) {
        guard let itemId = item["id"] as? String, let type = item["type"] as? String else { return }
        
        Task {
            do {
                try await SupabaseManager.shared.forkItem(itemId: itemId, type: type)
                print("Successfully forked \(type)")
            } catch {
                print("Fork failed: \(error)")
            }
        }
    }
}

struct CommunityCard: View {
    let item: [String: Any]
    let onFork: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isCompact: Bool {
        Theme.isPhone || horizontalSizeClass == .compact
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                let type = item["type"] as? String ?? "note"
                HStack(spacing: 6) {
                    Image(systemName: type == "note" ? "filemenu.and.selection" : "rectangle.stack.fill")
                    Text(type.uppercased())
                }
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(type == "note" ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                .foregroundColor(type == "note" ? .blue : .green)
                .cornerRadius(6)
                
                if let module = item["module_name"] as? String, !module.isEmpty {
                    Text(module)
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.purple.opacity(0.1))
                        .foregroundColor(.purple)
                        .cornerRadius(6)
                }
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "flag")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.4))
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 28, height: 28)
                        .overlay(Image(systemName: "person.fill").font(.system(size: 14)).foregroundColor(Theme.Colors.textSecondary))
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item["author_name"] as? String ?? "Anonymous")
                            .font(Theme.Fonts.inter(size: 13, weight: .bold))
                        if let uni = item["university"] as? String, !uni.isEmpty {
                            Text(uni)
                                .font(Theme.Fonts.inter(size: 11))
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.8))
                        }
                    }
                }
                
                Text(item["title"] as? String ?? "Untitled")
                    .font(Theme.Fonts.playfair(size: 22, weight: .bold))
                    .lineLimit(2)
                    .padding(.top, 4)
                
                Text(item["preview"] as? String ?? "Study materials for legal analysis.")
                    .font(Theme.Fonts.inter(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(3)
                    .padding(.top, 2)
            }
            
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red.opacity(0.7))
                    Text("\(item["upvotes"] as? Int ?? 0)")
                        .font(Theme.Fonts.inter(size: 14, weight: .bold))
                }
                .foregroundColor(Theme.Colors.textSecondary)
                
                Spacer()
                
                Button(action: onFork) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.branch")
                        Text("Fork to My Notes")
                    }
                    .font(Theme.Fonts.inter(size: 14, weight: .bold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.Colors.bg)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                }
            }
        }
        .padding(isCompact ? 16 : 24)
        .background(Theme.Colors.surface)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.02), radius: 10, x: 0, y: 5)
    }
}
