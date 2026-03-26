import SwiftUI

struct ReceptionView: View {
    @ObservedObject var collaborationManager = CollaborationManager.shared
    
    var body: some View {
        VStack {
            ForEach(collaborationManager.activeUsers) { user in
                if let content = user.broadcastContent, let type = user.broadcastType {
                    BroadcastToast(user: user, content: content, type: type)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            Spacer()
        }
        .padding(.top, 60)
        .allowsHitTesting(false) // Let touches pass through to editor unless we add "Accept" button
    }
}

struct BroadcastToast: View {
    let user: OnlineUser
    let content: String
    let type: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.Colors.accent)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(user.fullName.prefix(1)))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.Colors.onAccent)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(user.fullName)
                    .font(Theme.Fonts.inter(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary)
                
                HStack {
                    Image(systemName: type == "highlight" ? "highlighter" : "doc.text.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.accent)
                    
                    Text("SHARED A \(type.uppercased())")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(Theme.Colors.accent)
                }
                
                Text(content)
                    .font(Theme.Fonts.inter(size: 13, weight: .medium))
                    .lineLimit(2)
                    .foregroundColor(Theme.Colors.textPrimary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .padding()
        .background(Theme.Colors.surface)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.glassBorder, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
        .padding(.horizontal)
        .frame(maxWidth: 400)
    }
}
