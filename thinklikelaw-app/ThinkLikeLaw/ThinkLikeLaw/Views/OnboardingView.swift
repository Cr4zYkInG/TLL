import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var authState: AuthState
    @State private var currentPage = 0
    @State private var selectedLevel: EducationLevel? = nil
    @State private var universitySearch = ""
    @State private var selectedUniversity: String? = nil
    @State private var showSuggestions = false
    
    let onboardingSteps = [
        OnboardingStep(
            title: "Summarize Notes",
            description: "Turn dense lectures into high-distinction IRAC arguments in seconds.",
            icon: "sparkles",
            color: Color.blue
        ),
        OnboardingStep(
            title: "OSCOLA Auditing",
            description: "Automatic legal citation verification that keeps your essays compliant.",
            icon: "checkmark.seal.fill",
            color: Color.purple
        ),
        OnboardingStep(
            title: "Exam Mastery",
            description: "Get real-time feedback against A-Level and LLB mark schemes.",
            icon: "graduationcap.fill",
            color: Color(white: 0.5)
        ),
        OnboardingStep(
            title: "Your Level",
            description: "Choose your current path to specialize Ben's legal feedback.",
            icon: "book.fill",
            color: Color(white: 0.3)
        ),
        OnboardingStep(
            title: "Your Chambers",
            description: "Where are you studying this year?",
            icon: "building.columns.fill",
            color: Color(white: 0.7)
        )
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
        
        ZStack {
            BackgroundEffectView(color: onboardingSteps[currentPage].color)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress Dots
                HStack(spacing: 8) {
                    ForEach(0..<onboardingSteps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == currentPage ? onboardingSteps[currentPage].color : Theme.Colors.textSecondary.opacity(0.2))
                            .frame(width: index == currentPage ? 24 : 8, height: 8)
                    }
                }
                .padding(.top, isLandscape ? 20 : 60)
                
                // Content Carousel
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingSteps.count, id: \.self) { index in
                        switch index {
                        case onboardingSteps.count - 2:
                            LevelSelectionView(selectedLevel: $selectedLevel)
                                .tag(index)
                        case onboardingSteps.count - 1:
                            UniversitySelectionView(
                                universitySearch: $universitySearch,
                                selectedUniversity: $selectedUniversity,
                                showSuggestions: $showSuggestions
                            )
                            .tag(index)
                        default:
                            OnboardingStepContent(step: onboardingSteps[index])
                                .tag(index)
                        }
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                
                // Actions
                VStack(spacing: isLandscape ? 8 : 16) {
                    if currentPage == onboardingSteps.count - 1 {
                        Button(action: {
                            if let level = selectedLevel {
                                authState.setEducationLevel(level)
                                if let uni = selectedUniversity {
                                    authState.setUniversity(uni)
                                } else if !universitySearch.isEmpty {
                                    authState.setUniversity(universitySearch)
                                }
                                authState.completeOnboarding()
                            }
                        }) {
                            Text("Start Your Journey")
                                .font(Theme.Fonts.inter(size: isLandscape ? 16 : 18, weight: .bold))
                                .foregroundColor(Theme.Colors.onAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isLandscape ? 12 : 18)
                                .background(isStepComplete ? onboardingSteps[currentPage].color : Color.gray)
                                .cornerRadius(16)
                                .shadow(color: onboardingSteps[currentPage].color.opacity(0.3), radius: 10, y: 5)
                        }
                        .disabled(!isStepComplete)
                    } else {
                        Button(action: {
                            withAnimation(.spring()) {
                                currentPage += 1
                            }
                        }) {
                            Text("Continue")
                                .font(Theme.Fonts.inter(size: isLandscape ? 16 : 18, weight: .bold))
                                .foregroundColor(Theme.Colors.onAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, isLandscape ? 12 : 18)
                                .background(isStepComplete ? onboardingSteps[currentPage].color : Color.gray)
                                .cornerRadius(16)
                                .shadow(color: onboardingSteps[currentPage].color.opacity(0.3), radius: 10, y: 5)
                        }
                        .disabled(!isStepComplete)
                    }
                    
                    if !isLandscape {
                        Button(action: {
                            authState.enterGuestMode()
                        }) {
                            Text("Explore as Guest")
                                .font(Theme.Fonts.inter(size: 14, weight: .semibold))
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, isLandscape ? 10 : 0)
            }
        }
    }
    
    private var isStepComplete: Bool {
        switch currentPage {
        case onboardingSteps.count - 2:
            return selectedLevel != nil
        case onboardingSteps.count - 1:
            return !universitySearch.isEmpty || selectedUniversity != nil
        default:
            return true
        }
    }
}

// MARK: - Subviews

struct UniversitySelectionView: View {
    @Binding var universitySearch: String
    @Binding var selectedUniversity: String?
    @Binding var showSuggestions: Bool
    
    var filteredUniversities: [String] {
        if universitySearch.isEmpty { return [] }
        return UniversityData.llbUniversities.filter { $0.lowercased().contains(universitySearch.lowercased()) && $0 != selectedUniversity }
    }
    
    #if os(iOS)
    @Environment(\.verticalSizeClass) var verticalSizeClass
    #endif
    
    var body: some View {
        #if os(iOS)
        let isLandscape = verticalSizeClass == .compact
        #else
        let isLandscape = false
        #endif
        VStack(spacing: isLandscape ? 10 : 30) {
            Text("Your Chambers")
                .font(Theme.Fonts.inter(size: isLandscape ? 24 : 32, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "building.columns.fill")
                        .foregroundColor(Theme.Colors.accent)
                    
                    TextField("Search your University...", text: $universitySearch)
                        .font(Theme.Fonts.inter(size: 18))
                        .onChange(of: universitySearch) { oldValue, newValue in
                            showSuggestions = true
                            if selectedUniversity != newValue {
                                selectedUniversity = nil
                            }
                        }
                }
                .padding(20)
                .background(Theme.Colors.surface)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                )
                
                if showSuggestions && !filteredUniversities.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(filteredUniversities.prefix(5), id: \.self) { uni in
                                    Button(action: {
                                        universitySearch = uni
                                        selectedUniversity = uni
                                        showSuggestions = false
                                    }) {
                                        Text(uni)
                                            .font(Theme.Fonts.inter(size: 16))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                            .padding(.vertical, 14)
                                            .padding(.horizontal, 20)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    Divider().padding(.horizontal, 20)
                                }
                            }
                        }
                        .frame(maxHeight: 250)
                    }
                    .background(Theme.Colors.surface)
                    .cornerRadius(16)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                }
            }
            .padding(.horizontal, 30)
            
            if !isLandscape {
                Text("Don't see your institution? Just type it in and we'll remember it.")
                    .font(Theme.Fonts.inter(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }
            
            Spacer()
        }
    }
}

struct OnboardingStepContent: View {
    let step: OnboardingStep
    
    #if os(iOS)
    @Environment(\.verticalSizeClass) var verticalSizeClass
    #endif
    
    var body: some View {
        #if os(iOS)
        let isLandscape = verticalSizeClass == .compact
        #else
        let isLandscape = false
        #endif
        VStack(spacing: isLandscape ? 20 : 40) {
            ZStack {
                Circle()
                    .fill(step.color.opacity(0.15))
                    .frame(width: isLandscape ? 120 : 220, height: isLandscape ? 120 : 220)
                    .blur(radius: isLandscape ? 10 : 20)
                
                Image(systemName: step.icon)
                    .font(.system(size: isLandscape ? 50 : 90))
                    .foregroundColor(step.color)
                    .shadow(color: step.color.opacity(0.4), radius: 20)
            }
            
            VStack(spacing: isLandscape ? 10 : 20) {
                Text(step.title)
                    .font(Theme.Fonts.inter(size: isLandscape ? 24 : 32, weight: .bold))
                    .foregroundColor(Theme.Colors.textPrimary)
                
                Text(step.description)
                    .font(Theme.Fonts.inter(size: isLandscape ? 15 : 17))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(isLandscape ? 2 : 4)
                    .padding(.horizontal, 40)
            }
        }
    }
}

struct LevelSelectionView: View {
    @Binding var selectedLevel: EducationLevel?
    
    #if os(iOS)
    @Environment(\.verticalSizeClass) var verticalSizeClass
    #endif
    
    var body: some View {
        #if os(iOS)
        let isLandscape = verticalSizeClass == .compact
        #else
        let isLandscape = false
        #endif
        VStack(spacing: isLandscape ? 10 : 30) {
            Text("Select Your Path")
                .font(Theme.Fonts.inter(size: isLandscape ? 24 : 32, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
            
            HStack(spacing: 16) {
                ForEach(EducationLevel.allCases, id: \.self) { level in
                    Button(action: {
                        withAnimation(.spring()) {
                            selectedLevel = level
                        }
                    }) {
                        HStack {
                            Text(level.rawValue)
                                .font(Theme.Fonts.inter(size: isLandscape ? 14 : 18, weight: .semibold))
                            Spacer()
                            if selectedLevel == level {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Theme.Colors.accent)
                            }
                        }
                        .padding(.vertical, isLandscape ? 14 : 20)
                        .padding(.horizontal, 24)
                        .background(
                            Theme.Colors.surface
                        )
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedLevel == level ? Theme.Colors.accent : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 30)
            
            if !isLandscape {
                Text("This tailors our AI and study systems to your specific curriculum.")
                    .font(Theme.Fonts.inter(size: 14))
                    .foregroundColor(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }
            
            Spacer()
        }
    }
}

struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
    let color: Color
}
