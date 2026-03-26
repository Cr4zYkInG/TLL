import SwiftUI

struct SignupView: View {
    @EnvironmentObject var authState: AuthState
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var universitySearch = ""
    @State private var selectedUniversity: String? = nil
    @State private var showSuggestions = false
    @State private var level: EducationLevel = .llb
    @State private var localErrorMessage: String? = nil
    
    @Environment(\.openURL) var openURL
    #if os(iOS)
    @Environment(\.verticalSizeClass) var verticalSizeClass
    #endif
    
    var body: some View {
        #if os(iOS)
        let isLandscape = verticalSizeClass == .compact
        #else
        let isLandscape = false
        #endif
        
        ZStack {
            BackgroundEffectView(color: Theme.Colors.accent)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: isLandscape ? 16 : 30) {
                    // Ben Mascot Header
                    VStack(spacing: 20) {
                        BenCharacter(state: .happy)
                            .frame(width: 100, height: 100)
                            .shadow(color: Theme.Colors.accent.opacity(0.1), radius: 15, y: 8)
                        
                        VStack(spacing: 8) {
                            Text("Create Account")
                                .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                            Text("Join 5,000+ law students matching the mark scheme.")
                                .font(.custom("Inter-Regular", size: 14))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(.top, isLandscape ? 30 : 50)
                    
                    VStack(spacing: isLandscape ? 12 : 20) {
                        HStack(spacing: 16) {
                            CustomTextField(placeholder: "First Name", text: $firstName, icon: "person")
                            CustomTextField(placeholder: "Last Name", text: $lastName, icon: "")
                        }
                        
                        CustomTextField(placeholder: "Email", text: $email, icon: "envelope")
                        CustomSecureField(placeholder: "Password", text: $password, icon: "lock")
                        
                        // University Search
                        VStack(alignment: .leading, spacing: 8) {
                            CustomTextField(placeholder: "University / Institution", text: $universitySearch, icon: "building.columns")
                                .onChange(of: universitySearch) { oldValue, newValue in
                                    showSuggestions = true
                                    if selectedUniversity != newValue {
                                        selectedUniversity = nil
                                    }
                                }
                            
                            if showSuggestions && !filteredUniversities.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(filteredUniversities.prefix(5), id: \.self) { uni in
                                            Button(action: {
                                                universitySearch = uni
                                                selectedUniversity = uni
                                                showSuggestions = false
                                            }) {
                                                Text(uni)
                                                    .font(Theme.Fonts.inter(size: 14))
                                                    .foregroundColor(Theme.Colors.textPrimary)
                                                    .padding(.vertical, 10)
                                                    .padding(.horizontal, 16)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            Divider().padding(.horizontal, 16)
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                                .background(Theme.Colors.surface)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.1), radius: 5)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: isLandscape ? 8 : 12) {
                            Text("Current Level")
                                .font(Theme.Fonts.inter(size: 14, weight: .bold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.leading, 4)
                            
                            HStack(spacing: 12) {
                                ForEach(EducationLevel.allCases, id: \.self) { levelOption in
                                    Button(action: {
                                        withAnimation(.spring()) {
                                            level = levelOption
                                        }
                                    }) {
                                            HStack {
                                                Text(levelOption == .llb ? "LLB" : "A-Level")
                                                    .font(Theme.Fonts.inter(size: 14, weight: .semibold))
                                                Spacer()
                                                if level == levelOption {
                                                    Image(systemName: "checkmark.circle.fill")
                                                }
                                            }
                                            .padding(.vertical, 12)
                                            .padding(.horizontal, 16)
                                            .frame(maxWidth: .infinity)
                                            .background(level == levelOption ? Theme.Colors.accent : Theme.Colors.surface)
                                            .foregroundColor(level == levelOption ? Theme.Colors.onAccent : Theme.Colors.textPrimary)
                                            .cornerRadius(10)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    if let error = localErrorMessage ?? authState.errorMessage {
                        Text(error)
                            .font(Theme.Fonts.inter(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        handleSignup()
                    }) {
                            if authState.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.onAccent))
                            } else {
                                Text("Create Account")
                                    .font(Theme.Fonts.inter(size: 18, weight: .bold))
                                    .foregroundColor(Theme.Colors.onAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Theme.Colors.accent)
                                    .cornerRadius(14)
                                    .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 10, y: 5)
                            }
                    }
                    .padding(.horizontal, 24)
                    .disabled(authState.isLoading)
                    
                    VStack(spacing: 4) {
                        Text("By signing up, you agree to our")
                            .font(Theme.Fonts.inter(size: 12))
                            .foregroundColor(Theme.Colors.textSecondary)
                        
                        HStack(spacing: 4) {
                            Button(action: {
                                if let url = URL(string: "https://www.thinklikelaw.com/terms") {
                                    openURL(url)
                                }
                            }) {
                                Text("Terms of Service")
                                    .font(Theme.Fonts.inter(size: 12, weight: .bold))
                                    .foregroundColor(Theme.Colors.accent)
                                    .underline()
                            }
                            
                            Text("&")
                                .font(Theme.Fonts.inter(size: 12))
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            Button(action: {
                                if let url = URL(string: "https://www.thinklikelaw.com/privacy") {
                                    openURL(url)
                                }
                            }) {
                                Text("Privacy Policy")
                                    .font(Theme.Fonts.inter(size: 12, weight: .bold))
                                    .foregroundColor(Theme.Colors.accent)
                                    .underline()
                            }
                        }
                    }
                    .padding(.top, isLandscape ? 4 : 10)
                }
                .padding(.bottom, 40)
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
    
    private var filteredUniversities: [String] {
        if universitySearch.isEmpty { return [] }
        return UniversityData.llbUniversities.filter { $0.lowercased().contains(universitySearch.lowercased()) && $0 != selectedUniversity }
    }
    
    func handleSignup() {
        guard !firstName.isEmpty, !lastName.isEmpty, !email.isEmpty, !password.isEmpty else {
            localErrorMessage = "Please fill in all required fields."
            return
        }
        
        Task {
            await authState.signup(
                firstName: firstName,
                lastName: lastName,
                email: email,
                password: password,
                university: selectedUniversity ?? universitySearch,
                level: level
            )
        }
    }
}

#Preview {
    SignupView()
        .environmentObject(AuthState())
}
