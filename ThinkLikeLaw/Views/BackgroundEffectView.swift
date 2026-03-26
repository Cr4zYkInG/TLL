import SwiftUI

struct BackgroundEffectView: View {
    @State private var phase: CGFloat = 0
    let color: Color
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            // Animated Grid
            GeometryReader { geo in
                Path { path in
                    let step: CGFloat = 40
                    
                    // Vertical lines
                    for x in stride(from: 0, through: geo.size.width + step, by: step) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    
                    // Horizontal lines
                    for y in stride(from: 0, through: geo.size.height + step, by: step) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                }
                .stroke(color.opacity(0.12), lineWidth: 0.5)
                .offset(x: -phase, y: -phase)
            }
            .onAppear {
                withAnimation(.linear(duration: 30).repeatForever(autoreverses: false)) {
                    phase = 40
                }
            }
            
            // Subtle Glows
            Circle()
                .fill(color.opacity(0.12))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(color.opacity(0.08))
                .frame(width: 300, height: 300)
                .blur(radius: 60)
                .offset(x: 150, y: 250)
        }
    }
}

#if canImport(UIKit)
import UIKit
struct BlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
#elseif canImport(AppKit)
import AppKit
struct BlurView: NSViewRepresentable {
    let style: Any 
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .withinWindow
        view.material = .hudWindow // More premium, focused look for Mac
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) { }
}
#endif

#Preview {
    BackgroundEffectView(color: .blue)
}
