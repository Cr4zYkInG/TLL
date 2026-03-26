import SwiftUI

struct AIResultView: View {
    let result: String
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showCopySuccess = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        
                        MarkdownText(text: result)
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color(PlatformColor.windowBackgroundColor).opacity(0.5))
                                    .glassCard()
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        benMascotInsight
                        
                        actionButtons
                    }
                    .padding()
                }
                
                if showCopySuccess {
                    ToastView(message: "Copied to Clipboard!")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("AI Legal Analysis")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                }
            }
        }
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("INTELLIGENCE REPORT")
                    .font(Theme.Fonts.outfit(size: 12, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Theme.Colors.accent)
                
                Text("High-Fidelity Legal Feedback")
                    .font(Theme.Fonts.outfit(size: 20, weight: .bold))
            }
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 30))
                .foregroundColor(Theme.Colors.accent)
                .pulse()
        }
        .padding(.bottom, 10)
    }
    
    private var benMascotInsight: some View {
        HStack(spacing: 16) {
            Image("mascot_happy") // Assuming this exists or falls back to icon
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
                .background(Circle().fill(Theme.Colors.accent.opacity(0.1)))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("BEN'S QUICK TAKE")
                    .font(Theme.Fonts.outfit(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.accent)
                
                Text("This analysis uses the IRAC method to ensure maximum academic impact. Perfect for your upcoming assessment!")
                    .font(Theme.Fonts.inter(size: 13))
                    .foregroundColor(Theme.Colors.textSecondary)
            }
        }
        .padding()
        .background(Theme.Colors.accent.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 16) {
            Button(action: copyToClipboard) {
                Label("Copy", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Button(action: { /* Logic to append to note */ }) {
                Label("Insert into Note", systemImage: "plus.square.on.square")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.Colors.accent)
                    .foregroundColor(Theme.Colors.onAccent)
                    .cornerRadius(12)
            }
        }
        .font(Theme.Fonts.inter(size: 14, weight: .bold))
        .padding(.top, 20)
    }
    
    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = result
        #endif
        withAnimation {
            showCopySuccess = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopySuccess = false
            }
        }
        AudioManager.shared.playSuccessHaptic()
    }
}

struct ToastView: View {
    let message: String
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(Theme.Fonts.inter(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(25)
                .padding(.bottom, 50)
        }
    }
}
