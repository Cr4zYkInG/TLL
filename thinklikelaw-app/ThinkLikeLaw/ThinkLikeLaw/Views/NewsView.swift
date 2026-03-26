import SwiftUI

struct NewsView: View {
    @State private var selectedTab: String = "Legal"
    @State private var articles: [NewsArticle] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    let categories = ["(Legal) Legislation News", "Parliamentary News", "Saved"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("News & Updates")
                    .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                Text("Stay informed with the latest legal and parliamentary news directly from official government sources.")
                    .font(Theme.Fonts.playfair(size: 16))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 24)
            
            // Custom Tab Bar
            HStack(spacing: 20) {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedTab = category
                        }
                    }) {
                        VStack(spacing: 12) {
                            Text(category)
                                .font(Theme.Fonts.outfit(size: 16, weight: selectedTab == category ? .bold : .medium))
                                .foregroundColor(selectedTab == category ? Theme.Colors.accent : Theme.Colors.textSecondary)
                            
                            Rectangle()
                                .fill(selectedTab == category ? Theme.Colors.accent : Color.clear)
                                .frame(height: 3)
                                .cornerRadius(2)
                        }
                    }
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            
            Divider().background(Theme.Colors.glassBorder)
            
            // Content
            ScrollView {
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Fetching latest headlines...")
                            .font(Theme.Fonts.inter(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        Text(error)
                            .font(Theme.Fonts.inter(size: 16))
                            .multilineTextAlignment(.center)
                        Button("Retry") {
                            fetchNews()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(40)
                } else if articles.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "newspaper")
                            .font(.system(size: 64))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.3))
                        Text("No articles found in this category.")
                            .font(Theme.Fonts.inter(size: 16))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 350, maximum: 500), spacing: 20)], spacing: 20) {
                        ForEach(articles) { article in
                            NewsCardView(article: article)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(Theme.Colors.bg.ignoresSafeArea())
        .onAppear {
            fetchNews()
        }
        .onChange(of: selectedTab) { _, _ in
            fetchNews()
        }
    }
    
    private func fetchNews() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let fetched: [NewsArticle]
                if selectedTab == "Saved" {
                    fetched = try await SupabaseManager.shared.getSavedNews()
                } else {
                    let category = selectedTab.contains("Legislation") ? "Legal" : "Parliamentary"
                    fetched = try await SupabaseManager.shared.fetchNewsArticles(category: category)
                }
                
                await MainActor.run {
                    self.articles = fetched
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load news. Please check your connection."
                    self.isLoading = false
                }
            }
        }
    }
}

struct NewsCardView: View {
    let article: NewsArticle
    @State private var showDetail = false
    @State private var isSaved = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image Placeholder
            Rectangle()
                .fill(Theme.Colors.surface)
                .frame(height: 180)
                .overlay(
                    Group {
                        if let imageUrl = article.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.3))
                            }
                        } else {
                            Image(systemName: "newspaper.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.Colors.textSecondary.opacity(0.2))
                        }
                    }
                )
                .clipped()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(article.source.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.accent.opacity(0.1))
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Button(action: toggleSave) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .foregroundColor(isSaved ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    }
                }
                
                Text(article.title)
                    .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                    .lineLimit(3)
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(article.snippet ?? "No snippet available for this publication.")
                    .font(Theme.Fonts.inter(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(3)
                
                HStack {
                    Text(formatDate(article.publishedAt))
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                    
                    Spacer()
                    
                    Button(action: { showDetail = true }) {
                        Text("Read More")
                            .font(Theme.Fonts.outfit(size: 14, weight: Font.Weight.bold))
                            .foregroundColor(Theme.Colors.accent)
                    }
                }
                .padding(.top, 8)
            }
            .padding(16)
        }
        .background(Theme.Colors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 5)
        .onTapGesture {
            showDetail = true
        }
        .sheet(isPresented: $showDetail) {
            NewsDetailView(article: article)
        }
        .onAppear {
            checkIfSaved()
        }
    }
    
    private func toggleSave() {
        Task {
            do {
                try await SupabaseManager.shared.toggleSaveNews(articleId: article.id, isSaving: !isSaved)
                await MainActor.run {
                    self.isSaved.toggle()
                }
            } catch {
                print("Toggle save error: \(error)")
            }
        }
    }
    
    private func checkIfSaved() {
        // This is a bit inefficient to check every card, but simple for now
        // In a real app, the articles would come with an is_saved flag from the join
        Task {
            do {
                let saved = try await SupabaseManager.shared.getSavedNews()
                await MainActor.run {
                    self.isSaved = saved.contains(where: { $0.id == article.id })
                }
            } catch {}
        }
    }
    
    private func formatDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return isoString
    }
}

struct NewsDetailView: View {
    let article: NewsArticle
    @Environment(\.dismiss) var dismiss
    @State private var aiInterpretation: String?
    @State private var isInterpreting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(article.source.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Colors.accent)
                        
                        Text(article.title)
                            .font(Theme.Fonts.outfit(size: 28, weight: .bold))
                    }
                    
                    if let interpretation = aiInterpretation {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.purple)
                                Text("AI Interpretation")
                                    .font(Theme.Fonts.outfit(size: 18, weight: .bold))
                            }
                            
                            MarkdownText(text: interpretation)
                        }
                        .padding(20)
                        .background(Color.purple.opacity(0.05))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                        )
                    } else {
                        Button(action: interpretWithAI) {
                            HStack {
                                if isInterpreting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "sparkles")
                                }
                                Text(isInterpreting ? "Interpreting..." : "Interpret with AI (15 Credits)")
                            }
                            .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(12)
                        }
                        .disabled(isInterpreting)
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 14))
                                .foregroundColor(.red)
                                .padding(.top, 4)
                        }
                    }
                    
                    Text(article.snippet ?? "This official publication does not have a summary snippet. You can read the full text via the source link below.")
                        .font(Theme.Fonts.inter(size: 18))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineSpacing(6)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Government portals often block full embedding. You can read the complete publication on the official source:")
                            .font(Theme.Fonts.inter(size: 14))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        if let url = URL(string: article.url) {
                            Link(destination: url) {
                                HStack {
                                    Text("Read Official Publication")
                                    Image(systemName: "arrow.up.right")
                                }
                                .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 14)
                                .background(Theme.Colors.textPrimary)
                                .cornerRadius(10)
                            }
                        }
                    }
                    .padding(.top, 20)
                }
                .padding(32)
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func interpretWithAI() {
        isInterpreting = true
        errorMessage = nil
        
        Task {
            do {
                let context: [String: Any] = [
                    "title": article.title,
                    "source": article.source,
                    "url": article.url,
                    "system": "You are a specialized legal analyst for ThinkLikeLaw. Provide a high-level legal insight for this news article. Focus on legislation details, parliamentary impact, and student-relevant legal principles (LLB/A-Level). AVOID generic nonsense about construction or unrelated industries unless specifically mentioned in the text. Be academic and rigourous."
                ]
                
                let (interpretation, _) = try await AIService.shared.callAI(
                    tool: .interpret_news,
                    content: "Analyze this legal update: \(article.snippet ?? article.title)",
                    context: context
                )
                
                await MainActor.run {
                    self.aiInterpretation = interpretation
                    self.isInterpreting = false
                }
            } catch {
                await MainActor.run {
                    self.isInterpreting = false
                    // Simple error handling here, could add errorMessage state to DetailView too
                }
            }
        }
    }
}
