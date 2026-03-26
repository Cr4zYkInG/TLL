import SwiftUI
import Combine

struct LandingView: View {
    @EnvironmentObject var authState: AuthState
    @State private var spotlightIndex = 0
    let spotlightTimer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()
    
    let spotlights = [
        Spotlight(title: "Master the Law.", subtitle: "Own the Mark Scheme.", description: "ThinkLikeLaw transforms lecture notes into top-tier IRAC arguments in seconds.", icon: "sparkles", color: .primary),
        Spotlight(title: "Cite with Power.", subtitle: "Automatic OSCOLA.", description: "Our editorial audit catches citation errors before they reach your tutor.", icon: "checkmark.seal.fill", color: .secondary),
        Spotlight(title: "Ace Every Exam.", subtitle: "Timed Simulations.", description: "Face realistic LLB and A-Level pressure with real-time feedback.", icon: "graduationcap.fill", color: Color.secondary)
    ]
    
    #if os(iOS)
    @Environment(\.verticalSizeClass) var verticalSizeClass
    #endif
    
    var body: some View {
        #if os(iOS)
        let isLandscape = verticalSizeClass == .compact
        #else
        let isLandscape = false
        #endif
        
        NavigationStack {
            ZStack {
                BackgroundEffectView(color: spotlights[spotlightIndex].color)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Logo Header
                    VStack(spacing: isLandscape ? 8 : 20) {
                        LogoView()
                            .frame(height: isLandscape ? 40 : 80)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    .padding(.top, isLandscape ? 20 : 60)
                    
                    if !isLandscape { Spacer() }
                    
                    // Feature Spotlight Carousel
                    TabView(selection: $spotlightIndex) {
                        ForEach(0..<spotlights.count, id: \.self) { index in
                            VStack(spacing: isLandscape ? 12 : 24) {
                                Image(systemName: spotlights[index].icon)
                                    .font(.system(size: isLandscape ? 30 : 60))
                                    .foregroundColor(spotlights[index].color)
                                    .padding(isLandscape ? 10 : 20)
                                    .background(spotlights[index].color.opacity(0.1))
                                    .clipShape(Circle())
                                    .shadow(color: spotlights[index].color.opacity(0.2), radius: 20)
                                
                                VStack(spacing: isLandscape ? 4 : 12) {
                                    Text(spotlights[index].title)
                                        .font(Theme.Fonts.inter(size: isLandscape ? 24 : 36, weight: .bold))
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    
                                    Text(spotlights[index].subtitle)
                                        .italic()
                                        .font(Theme.Fonts.playfair(size: isLandscape ? 16 : 24))
                                        .foregroundColor(spotlights[index].color)
                                }
                                
                                if !isLandscape {
                                    Text(spotlights[index].description)
                                        .font(Theme.Fonts.inter(size: 17))
                                        .foregroundColor(Theme.Colors.textSecondary)
                                        .multilineTextAlignment(.center)
                                        .lineSpacing(4)
                                        .padding(.horizontal, 40)
                                        .frame(height: 80)
                                }
                            }
                            .tag(index)
                        }
                    }
                    #if os(iOS)
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    #endif
                    .frame(height: isLandscape ? 150 : 350)
                    
                    // Progress Indicator
                    HStack(spacing: 8) {
                        ForEach(0..<spotlights.count, id: \.self) { index in
                            Circle()
                                .fill(index == spotlightIndex ? spotlights[index].color : Theme.Colors.textSecondary.opacity(0.2))
                                .frame(width: 8, height: 8)
                                .scaleEffect(index == spotlightIndex ? 1.2 : 1.0)
                                .animation(.spring(), value: spotlightIndex)
                        }
                    }
                    .padding(.bottom, isLandscape ? 10 : 40)
                    
                    if !isLandscape { Spacer() }
                    
                    // Actions
                    VStack(spacing: isLandscape ? 8 : 16) {
                        NavigationLink(destination: LoginView()) {
                            HStack {
                                Text("Enter Chambers")
                                    .font(Theme.Fonts.inter(size: isLandscape ? 16 : 18, weight: .bold))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .foregroundColor(Theme.Colors.onAccent)
                            .padding(.vertical, isLandscape ? 12 : 18)
                            .frame(maxWidth: isLandscape ? 300 : .infinity)
                            .background(Theme.Colors.accent)
                            .cornerRadius(100)
                            .shadow(color: Theme.Colors.accent.opacity(0.3), radius: 15, y: 8)
                        }
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                authState.enterGuestMode()
                            }
                        }) {
                            Text("Explore as Guest")
                                .font(Theme.Fonts.inter(size: 14, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(.top, isLandscape ? 0 : 8)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, isLandscape ? 20 : 60)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            #if os(iOS)
            .navigationBarHidden(true)
            #endif
        }
        .onReceive(spotlightTimer) { _ in
            withAnimation(.easeInOut(duration: 1.0)) {
                spotlightIndex = (spotlightIndex + 1) % spotlights.count
            }
        }
    }
}

struct Spotlight {
    let title: String
    let subtitle: String
    let description: String
    let icon: String
    let color: Color
}


#Preview {
    LandingView()
        .environmentObject(AuthState())
}
