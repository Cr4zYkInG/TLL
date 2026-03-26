import SwiftUI

struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    var cornerRadius: CGFloat = 16
    var shadowRadius: CGFloat = 8
    
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: shadowRadius, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 8) -> some View {
        self.modifier(GlassCard(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
}

struct GlassCard_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack {
                Text("ThinkLikeLaw")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Master the Law. Own the Mark Scheme.")
                    .font(.subheadline)
            }
            .padding()
            .glassCard()
            .padding()
        }
    }
}
