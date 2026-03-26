import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    
    // Account Settings
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var university: String = ""
    @State private var targetYear: String = ""
    @State private var currentStatus: String = "llb"
    @State private var examBoard: String = "aqa"
    @State private var leaderboardUsername: String = ""
    @State private var isAnonymous: Bool = false
    @State private var avatarUrl: String? = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var isUploadingAvatar = false
    
    // Preferences (AppStorage for local persistence)
    @AppStorage("audioMasterEnabled") var audioMasterEnabled: Bool = true
    @AppStorage("audioMascotEnabled") var audioMascotEnabled: Bool = true
    @AppStorage("audioTypingEnabled") var audioTypingEnabled: Bool = true
    @AppStorage("audioMusicEnabled") var audioMusicEnabled: Bool = true
    @AppStorage("mascotVisible") var mascotVisible: Bool = true
    @AppStorage("aiPlusEnabled") var aiPlusEnabled: Bool = false
    @AppStorage("onlyPencilDraws") var onlyPencilDraws: Bool = true
    @AppStorage("fingerScrollEnabled") var fingerScrollEnabled: Bool = true
    
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var activeTab: SettingsTab = .account
    
    enum SettingsTab {
        case account, subscription, preferences, stationery, legal
    }
    
    @State private var showingDeleteAlert = false
    @State private var showingClearSuccess = false
    
    @Environment(\.horizontalSizeClass) var sizeClass
    
    var body: some View {
        if sizeClass == .compact {
            // iPhone Responsive Layout
            NavigationStack {
                List {
                    Section("Common") {
                        NavigationLink(destination: ScrollView { accountSection }.padding().background(Theme.Colors.bg)) {
                            Label("Account", systemImage: "person.fill")
                        }
                        NavigationLink(destination: ScrollView { subscriptionSection }.padding().background(Theme.Colors.bg)) {
                            Label("Subscription", systemImage: "creditcard.fill")
                        }
                    }
                    
                    Section("App Settings") {
                        NavigationLink(destination: ScrollView { preferencesSection }.padding().background(Theme.Colors.bg)) {
                            Label("Preferences", systemImage: "slider.horizontal.3")
                        }
                        NavigationLink(destination: ScrollView { stationerySection }.padding().background(Theme.Colors.bg)) {
                            Label("Stationery", systemImage: "pencil.and.outline")
                        }
                    }
                    
                    Section("Support") {
                        NavigationLink(destination: ScrollView { legalSection }.padding().background(Theme.Colors.bg)) {
                            Label("Legal & Support", systemImage: "shield.fill")
                        }
                    }
                    
                    Section {
                        Button(role: .destructive, action: { authState.logout() }) {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                }
                .navigationTitle("Me")
                .background(Theme.Colors.bg)
            }
        } else {
            // iPad / Desktop Premium Sidebar
            HStack(spacing: 0) {
                // Sidebar Navigation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Settings")
                        .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                        .padding(.bottom, 20)
                    
                    SettingsNavItem(icon: "person.fill", label: "Account", isActive: activeTab == .account) { activeTab = .account }
                    SettingsNavItem(icon: "creditcard.fill", label: "Subscription", isActive: activeTab == .subscription) { activeTab = .subscription }
                    SettingsNavItem(icon: "slider.horizontal.3", label: "Preferences", isActive: activeTab == .preferences) { activeTab = .preferences }
                    SettingsNavItem(icon: "pencil.and.outline", label: "Stationery", isActive: activeTab == .stationery) { activeTab = .stationery }
                    SettingsNavItem(icon: "shield.fill", label: "Legal & Support", isActive: activeTab == .legal) { activeTab = .legal }
                    
                    Spacer()
                    
                    Button(action: { authState.logout() }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                        .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }
                }
                .frame(width: 280)
                .padding(32)
                .background(Theme.Colors.surface)
                .overlay(
                    Rectangle()
                        .fill(Theme.Colors.glassBorder)
                        .frame(width: 1),
                    alignment: .trailing
                )
                
                // Main Content Area
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        switch activeTab {
                        case .account: accountSection
                        case .subscription: subscriptionSection
                        case .preferences: preferencesSection
                        case .stationery: stationerySection
                        case .legal: legalSection
                        }
                    }
                    .padding(48)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Theme.Colors.bg.ignoresSafeArea())
            .onAppear(perform: loadUserData)
            .onChange(of: audioMasterEnabled) { old, new in AudioManager.shared.updateMusicState() }
            .onChange(of: audioMusicEnabled) { old, new in AudioManager.shared.updateMusicState() }
            .overlay(saveSuccessOverlay)
        }
    }
    
    private var saveSuccessOverlay: some View {
        Group {
            if showSaveSuccess {
                VStack {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Settings Saved")
                            .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Theme.Colors.surface)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                .padding(.top, 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }
    
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Profile Information")
                .font(Theme.Fonts.outfit(size: 28, weight: .bold))
            
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 24) {
                    Group {
                        if isUploadingAvatar {
                            ProgressView()
                                .frame(width: 80, height: 80)
                                .background(Theme.Colors.accent.opacity(0.1))
                                .clipShape(Circle())
                        } else if let urlStr = avatarUrl, !urlStr.isEmpty, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { image in
                                image.resizable()
                                     .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Theme.Colors.accent.opacity(0.1))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text("\(firstName.prefix(1))\(lastName.prefix(1))")
                                        .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                                        .foregroundColor(Theme.Colors.accent)
                                )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        PhotosPicker(selection: $selectedItem, matching: .images) {
                            Text("Change Photo")
                                .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.Colors.surface)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                        }
                        .onChange(of: selectedItem) { oldItem, newItem in
                            if let newItem {
                                uploadAvatar(item: newItem)
                            }
                        }
                        
                        Text("Max 2MB (PNG/JPG).")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                
                HStack(spacing: 20) {
                    SettingsTextField(label: "First Name", text: $firstName)
                    SettingsTextField(label: "Last Name", text: $lastName)
                }
                
                SettingsTextField(label: "School / University", text: $university, isDisabled: true)
                SettingsTextField(label: "Target Qualification Year", text: $targetYear, placeholder: "e.g. 2026")
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("EDUCATION LEVEL")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Picker("", selection: $currentStatus) {
                            Text("LLB (Undergraduate)").tag("llb")
                            Text("A-Level Law").tag("alevel")
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(Theme.Colors.surface)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                    }
                    
                    if currentStatus == "alevel" {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("EXAM BOARD")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.Colors.textSecondary)
                            Picker("", selection: $examBoard) {
                                Text("AQA").tag("aqa")
                                Text("OCR").tag("ocr")
                                Text("Eduqas").tag("eduqas")
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Theme.Colors.surface)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                        }
                    } else {
                        Spacer()
                    }
                }
                
                Divider().background(Theme.Colors.glassBorder).padding(.vertical, 10)
                
                Text("Leaderboard Privacy")
                    .font(Theme.Fonts.outfit(size: 20, weight: .bold))
                
                SettingsTextField(label: "Leaderboard Username", text: $leaderboardUsername, placeholder: "e.g. kingoflaw (min 4 chars)")
                
                Toggle("Go Anonymous", isOn: $isAnonymous)
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                Text("If enabled, your name will appear as 'Anonymous' and your university will be hidden on the leaderboard.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(32)
            .background(Theme.Colors.surface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
            
            Button(action: saveProfile) {
                if isSaving {
                    ProgressView().tint(Theme.Colors.onAccent)
                } else {
                    Text("Save Changes")
                }
            }
            .font(Theme.Fonts.outfit(size: 18, weight: .bold))
            .foregroundColor(Theme.Colors.onAccent)
            .frame(width: 200, height: 50)
            .background(Theme.Colors.accent)
            .cornerRadius(12)
            .disabled(isSaving)
        }
    }
    
    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Subscription Plan")
                .font(Theme.Fonts.outfit(size: 28, weight: .bold))
            
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CURRENT PLAN")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(authState.currentUser?.plan.uppercased() ?? "SCHOLAR")
                            .font(Theme.Fonts.outfit(size: 24, weight: .bold))
                    }
                    Spacer()
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.Colors.accent)
                }
                .padding(32)
                .background(Theme.Colors.accent.opacity(0.05))
                
                Divider().background(Theme.Colors.glassBorder)
                
                VStack(alignment: .leading, spacing: 16) {
                    let planName = authState.currentUser?.plan.lowercased() ?? "scholar"
                    let isScholar = planName == "scholar"
                    
                    HStack {
                        Image(systemName: "bolt.fill").foregroundColor(.orange)
                        Text("\((authState.currentUser?.credits ?? 0).toLocaleString()) AI Credits Remaining")
                            .font(Theme.Fonts.inter(size: 16, weight: .bold))
                    }
                    
                    if isScholar {
                        Text("Your free monthly balance is generous for the beta season. Upgrade for a larger quota.")
                            .font(Theme.Fonts.inter(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                    
                    HStack {
                        Image(systemName: "checkmark").foregroundColor(.green)
                        Text("Unlimited Lecture Notes & Modules")
                    }
                    HStack {
                        Image(systemName: "checkmark").foregroundColor(.green)
                        Text(isScholar ? "Access to Issue Spotter & Simulator" : "Premium Suite: AI Marking & IRAC Simulation")
                    }
                }
                .font(Theme.Fonts.inter(size: 16))
                .padding(32)
                
                Divider().background(Theme.Colors.glassBorder)
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("All subscriptions are synced from our website. If you're looking to upgrade or manage billing, please head over to www.thinklikelaw.com.")
                        .font(Theme.Fonts.inter(size: 14))
                        .foregroundColor(Theme.Colors.textSecondary)
                        .lineSpacing(4)
                    
                    Button(action: { 
                        if let url = URL(string: "https://www.thinklikelaw.com") {
                            openURL(url)
                        }
                    }) {
                        HStack {
                            Text("Manage on Website")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(Theme.Colors.surface)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                    }
                }
                .padding(32)
            }
            .background(Theme.Colors.surface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        }
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Preferences")
                .font(Theme.Fonts.outfit(size: 28, weight: .bold))
            
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "Audio & Focus")
                ToggleRow(title: "Master Audio", isOn: $audioMasterEnabled)
                ToggleRow(title: "Mascot (Ben) Sounds", isOn: $audioMascotEnabled)
                ToggleRow(title: "Tactile Typing Feedback", isOn: $audioTypingEnabled)
                ToggleRow(title: "Chambers Music Player", isOn: $audioMusicEnabled)
                
                Divider().background(Theme.Colors.glassBorder)
                
                SectionHeader(title: "Mascot Companion")
                ToggleRow(title: "Show Ben the Cat", isOn: $mascotVisible)
                Text("Ben provides study tips, motivation, and companionship. Disable him for a distraction-free experience.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Divider().background(Theme.Colors.glassBorder)
                
                SectionHeader(title: "AI Intelligence")
                VStack(alignment: .leading, spacing: 12) {
                    let isPremium = authState.currentUser?.plan.lowercased() != "scholar"
                    
                    ToggleRow(title: "Enable AI Plus (Mistral-Large)", isOn: Binding(
                        get: { aiPlusEnabled && isPremium },
                        set: { if isPremium { aiPlusEnabled = $0 } }
                    ))
                    
                    if !isPremium {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("Upgrade to Starter to unlock advanced legal reasoning.")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.top, 4)
                    } else if aiPlusEnabled {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("AI Plus consumes ~3x more credits for smarter legal reasoning.")
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                    }
                }
            }
            .padding(32)
            .background(Theme.Colors.surface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        }
    }
    
    private var stationerySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Pen & Stationery")
                .font(Theme.Fonts.outfit(size: 28, weight: .bold))
            
            VStack(alignment: .leading, spacing: 24) {
                ToggleRow(title: "Only Apple Pencil Draws", isOn: $onlyPencilDraws)
                ToggleRow(title: "Finger Scrolling Support", isOn: $fingerScrollEnabled)
                
                Divider().background(Theme.Colors.glassBorder)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("STATIONERY THEME")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Theme.Colors.textSecondary)
                    HStack(spacing: 12) {
                        Circle().fill(Color.yellow.opacity(0.1)).frame(width: 40).overlay(Image(systemName: "pencil")).onTapGesture { }
                        Circle().fill(Color.blue.opacity(0.1)).frame(width: 40).overlay(Image(systemName: "highlighter")).onTapGesture { }
                        Circle().fill(Color.red.opacity(0.1)).frame(width: 40).overlay(Image(systemName: "eraser.fill")).onTapGesture { }
                    }
                }
            }
            .padding(32)
            .background(Theme.Colors.surface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        }
    }
    
    private func loadUserData() {
        if let user = authState.currentUser {
            firstName = user.firstName
            lastName = user.lastName
            university = user.university
            targetYear = user.targetYear != nil ? "\(user.targetYear!)" : ""
            currentStatus = user.currentStatus ?? "llb"
            examBoard = user.examBoard ?? "aqa"
            leaderboardUsername = user.leaderboardUsername ?? ""
            isAnonymous = user.isAnonymous
            avatarUrl = user.avatarUrl
        }
    }
    
    private func uploadAvatar(item: PhotosPickerItem) {
        isUploadingAvatar = true
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let uploadedUrl = try await SupabaseManager.shared.uploadAvatar(data: data)
                    
                    // Update profile with the new URL
                    try await SupabaseManager.shared.updateProfile(updates: ["avatar_url": uploadedUrl])
                    
                    await MainActor.run {
                        self.avatarUrl = uploadedUrl
                        self.isUploadingAvatar = false
                        authState.refreshProfile()
                    }
                }
            } catch {
                print("Error uploading avatar: \(error)")
                await MainActor.run {
                    self.isUploadingAvatar = false
                }
            }
        }
    }
    
    private var legalSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Legal & Support")
                .font(Theme.Fonts.outfit(size: 28, weight: .bold))
            
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(title: "Compliance")
                
                LegalLinkRow(title: "Privacy Policy", url: "https://www.thinklikelaw.com/privacy")
                LegalLinkRow(title: "Terms of Service", url: "https://www.thinklikelaw.com/terms")
                LegalLinkRow(title: "Contact Support", url: "mailto:support@thinklikelaw.com")
                
                Divider().background(Theme.Colors.glassBorder).padding(.vertical, 8)
                
                SectionHeader(title: "Danger Zone")
                Text("If you see ghost data or folders that don't belong to you, use the button below to wipe the local database. This will not affect your cloud data, which will re-sync on next launch.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Button(action: { 
                    NotificationCenter.default.post(name: .clearGuestData, object: nil)
                    withAnimation {
                        showingClearSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showingClearSuccess = false }
                    }
                }) {
                    HStack {
                        Image(systemName: showingClearSuccess ? "checkmark.circle.fill" : "broom.fill")
                        Text(showingClearSuccess ? "Cache Cleared" : "Clear Local Cache & Fix Sync")
                    }
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .foregroundColor(showingClearSuccess ? .green : Theme.Colors.textPrimary)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Theme.Colors.surface)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(showingClearSuccess ? Color.green : Theme.Colors.glassBorder, lineWidth: 1))
                }
                .disabled(showingClearSuccess)
                
                Text("Deleting your account will permanently erase all your modules, notes, deadlines, and study history from our cloud servers. This action cannot be undone.")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                Button(action: { showingDeleteAlert = true }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete My Account")
                    }
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 24)
                    .background(Color.red)
                    .cornerRadius(10)
                }
            }
            .padding(32)
            .background(Theme.Colors.surface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        }
        .alert("Permanently Delete Account?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Everything", role: .destructive) {
                Task {
                    await authState.deleteAccount()
                }
            }
        } message: {
            Text("Are you sure? This will wipe your academic progress on our cloud servers and local database forever.")
        }
    }

    private func saveProfile() {
        isSaving = true
        
        var updates: [String: Any] = [
            "first_name": firstName,
            "last_name": lastName,
            "current_status": currentStatus,
            "exam_board": examBoard,
            "leaderboard_username": leaderboardUsername,
            "is_anonymous": isAnonymous
        ]
        
        if let year = Int(targetYear) {
            updates["target_year"] = year
        }
        
        Task {
            do {
                try await SupabaseManager.shared.updateProfile(updates: updates)
                await MainActor.run {
                    isSaving = false
                    withAnimation {
                        showSaveSuccess = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSaveSuccess = false }
                    }
                    // Refresh local user profile
                    Task {
                        if UserDefaults.standard.string(forKey: "supabase_user_id") != nil {
                            authState.refreshProfile()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// Helper Components
struct SettingsNavItem: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(label)
                    .font(Theme.Fonts.outfit(size: 16, weight: isActive ? .bold : .medium))
            }
            .foregroundColor(isActive ? Theme.Colors.onAccent : Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isActive ? Theme.Colors.accent : Color.clear)
            .cornerRadius(12)
        }
    }
}

struct SettingsTextField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
    var isDisabled: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(Theme.Fonts.outfit(size: 13, weight: .semibold))
                .foregroundColor(Theme.Colors.textSecondary)
            
            TextField(placeholder, text: $text)
                .font(Theme.Fonts.inter(size: 16))
                .padding(14)
                .background(isDisabled ? Theme.Colors.surface.opacity(0.3) : Theme.Colors.surface)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.glassBorder, lineWidth: 1))
                .disabled(isDisabled)
        }
    }
}

struct ToggleRow: View {
    let title: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(title, isOn: $isOn)
            .font(Theme.Fonts.outfit(size: 16, weight: .medium))
            .toggleStyle(SwitchToggleStyle(tint: Theme.Colors.accent))
            .onChange(of: isOn) { old, new in
                AudioManager.shared.playTypingHaptic()
            }
    }
}

struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(Theme.Colors.textSecondary)
            .padding(.bottom, 4)
    }
}

struct LegalLinkRow: View {
    let title: String
    let url: String
    @Environment(\.openURL) var openURL
    
    var body: some View {
        Button(action: {
            if let targetUrl = URL(string: url) {
                openURL(targetUrl)
            }
        }) {
            HStack {
                Text(title)
                    .font(Theme.Fonts.outfit(size: 16, weight: .medium))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14))
            }
            .foregroundColor(Theme.Colors.textPrimary)
            .padding(.vertical, 8)
        }
    }
}
