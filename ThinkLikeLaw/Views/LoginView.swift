import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct LoginView: View {
    @EnvironmentObject var authState: AuthState
    @Environment(\.presentationMode) var presentationMode
    
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var appleAuthManager: AppleAuthManager?
    @State private var googleAuthManager: GoogleAuthManager?
    
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
                VStack(spacing: isLandscape ? 12 : 24) {
                    // Ben Mascot Header
                    VStack(spacing: 20) {
                        BenCharacter(state: .proud)
                            .frame(width: 120, height: 120)
                            .shadow(color: Theme.Colors.accent.opacity(0.15), radius: 20, y: 10)
                        
                        VStack(spacing: 8) {
                            Text("Sign In")
                                .font(Theme.Fonts.outfit(size: 32, weight: .bold))
                            Text("Access your academic chambers.")
                                .font(Theme.Fonts.inter(size: 16))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    }
                    .padding(.top, isLandscape ? 20 : 60)
                    
                    // Form
                    VStack(spacing: isLandscape ? 10 : 16) {
                        CustomTextField(placeholder: "Email", text: $email, icon: "envelope")
                        CustomSecureField(placeholder: "Password", text: $password, icon: "lock")
                    }
                    .padding(.horizontal, 24)
                    
                    if let error = errorMessage ?? authState.errorMessage {
                        Text(error)
                            .font(Theme.Fonts.inter(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Email Sign In
                    Button(action: {
                        handleLogin()
                    }) {
                        if authState.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Theme.Colors.onAccent))
                        } else {
                            Text("Sign In")
                                .font(Theme.Fonts.inter(size: 18, weight: .bold))
                                .foregroundColor(Theme.Colors.onAccent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.Colors.accent)
                    .cornerRadius(14)
                    .padding(.horizontal, 24)
                    .disabled(authState.isLoading)
                    
                    Button("Forgot Password?") {
                        // Logic for password reset
                    }
                    .font(Theme.Fonts.inter(size: 14, weight: .medium))
                    .foregroundColor(Theme.Colors.accent)
                    
                    // Divider
                    HStack {
                        Rectangle().fill(Theme.Colors.textSecondary.opacity(0.2)).frame(height: 1)
                        Text("OR").font(Theme.Fonts.inter(size: 12, weight: .bold)).foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                        Rectangle().fill(Theme.Colors.textSecondary.opacity(0.2)).frame(height: 1)
                    }
                    .padding(.horizontal, 40)
                    
                    // Social Auth Grid
                    VStack(spacing: 16) {
                        Text("Or Sign In With")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.6))
                        
                        VStack(spacing: 12) {
                            SocialGridButton(title: "Apple", icon: "apple.logo", color: Theme.Colors.textPrimary, textColor: Theme.Colors.bg) {
                                startAppleSignIn()
                            }
                            
                            #if canImport(GoogleSignIn)
                            SocialGridButton(title: "Google", icon: "g.circle.fill", color: Theme.Colors.surface, textColor: Theme.Colors.textPrimary) {
                                startGoogleSignIn()
                            }
                            #endif
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    // Toggle to Signup
                    HStack {
                        Text("New here?").foregroundColor(Theme.Colors.textSecondary)
                        NavigationLink("Create Account", destination: SignupView())
                            .font(Theme.Fonts.inter(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.accent)
                    }
                    .font(Theme.Fonts.inter(size: 14))
                    .padding(.vertical, 20)
                }
            }
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            self.appleAuthManager = AppleAuthManager(authState: authState)
            #if canImport(GoogleSignIn)
            self.googleAuthManager = GoogleAuthManager(authState: authState)
            #endif
        }
    }
    
    private func handleLogin() {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields."
            return
        }
        Task {
            await authState.login(email: email, password: password)
        }
    }
    
    private func startAppleSignIn() {
        appleAuthManager?.startAppleSignInFlow()
    }
    
    private func startGoogleSignIn() {
        googleAuthManager?.startGoogleSignInFlow()
    }
}

// ... (Subviews CustomTextField and CustomSecureField stay the same)

struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .font(Theme.Fonts.inter(size: 16))
                #if os(iOS)
                .autocapitalization(.none)
                #else
                .disableAutocorrection(true)
                #endif
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
    }
}

struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(Theme.Colors.textSecondary)
                .frame(width: 20)
            SecureField(placeholder, text: $text)
                .font(Theme.Fonts.inter(size: 16))
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
    }
}
struct SocialGridButton: View {
    let title: String
    let icon: String
    let color: Color
    let textColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(Theme.Fonts.inter(size: 16, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .opacity(0.3)
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(color)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
            )
        }
    }
}
