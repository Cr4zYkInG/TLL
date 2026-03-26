import SwiftUI
import Combine

struct MascotView: View {
    @ObservedObject var manager = MascotManager.shared
    @State private var isAnimating = false
    
    var body: some View {
        Group {
            if manager.isVisible {
                VStack(spacing: 8) {
                    // Speech Bubble
                    if manager.showBubble && !manager.currentSpeech.isEmpty {
                        Text(manager.currentSpeech)
                            .font(Theme.Fonts.inter(size: Theme.isPhone ? 12 : 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Theme.Colors.surface)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                            .transition(.asymmetric(insertion: .scale.combined(with: .opacity), removal: .opacity))
                            .frame(maxWidth: Theme.isPhone ? 200 : 250)
                    }
                    
                    // Ben the Cat - Premium Redesign
                    ZStack {
                        if manager.isThinking {
                            Circle()
                                .stroke(Theme.Colors.accent.opacity(0.3), lineWidth: 3)
                                .frame(width: 110, height: 110)
                                .rotationEffect(.degrees(isAnimating ? 360 : 0))
                                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isAnimating)
                                .onAppear { isAnimating = true }
                        }
                        
                        BenCharacter(state: manager.isThinking ? .thinking : manager.currentState)
                            .frame(width: Theme.isPhone ? 80 : 100, height: Theme.isPhone ? 80 : 100)
                            .onTapGesture {
                                manager.handleTap()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    isAnimating = true
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    isAnimating = false
                                }
                            }
                            .scaleEffect(isAnimating ? 1.1 : 1.0)
                            .scaleEffect(manager.isFlipped ? -1 : 1, anchor: .center)
                    }
                }
                .padding()
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(), value: manager.isVisible)
    }
}

struct BenCharacter: View {
    let state: MascotManager.MascotState
    @Environment(\.colorScheme) var colorScheme
    
    @State private var blink = false
    @State private var breathe = false
    @State private var tailWag = false
    
    // Theme logic: If dark mode, show white cat. If light mode, show black cat (matching the images)
    var catBaseColor: Color {
        colorScheme == .dark ? Color.white : Color(hex: "1A1A1A")
    }
    
    var eyeColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
    
    var body: some View {
        ZStack {
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.15))
                .frame(width: 70, height: 8)
                .offset(y: 45)
            
            // Tail - Improved visibility
            Path { path in
                path.move(to: CGPoint(x: 20, y: 50)) 
                path.addQuadCurve(to: CGPoint(x: 70, y: tailWag ? 10 : 50), control: CGPoint(x: 75, y: 65))
            }
            .stroke(catBaseColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
            .offset(x: 5, y: -5)
            .rotationEffect(.degrees(tailWag ? 15 : -5), anchor: .bottomLeading)
            
            // Body - Slimmer & Sleeker
            RoundedRectangle(cornerRadius: 32)
                .fill(catBaseColor)
                .frame(width: 65, height: 75) 
                .offset(y: 15)
                .scaleEffect(y: breathe ? 1.03 : 1.0, anchor: .bottom)
            
            // Gray belly patch (only for white cat to match image)
            if colorScheme == .dark {
                Circle()
                    .fill(Color.black.opacity(0.08))
                    .frame(width: 45, height: 35)
                    .offset(y: 20)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 45, height: 35)
                    .offset(y: 20)
            }
            
            // Ears
            HStack(spacing: 35) {
                BenEar(catColor: catBaseColor)
                BenEar(catColor: catBaseColor)
            }
            .offset(y: -44)
            
            // Head
            Circle()
                .fill(catBaseColor)
                .frame(width: 80, height: 80)
                .offset(y: -15)
            
            // Face
            VStack(spacing: 4) {
                // Whiskers
                ZStack {
                    HStack(spacing: 50) {
                        VStack(spacing: 4) {
                            Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 1.5)
                            Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 1.5)
                        }
                        VStack(spacing: 4) {
                            Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 1.5)
                            Rectangle().fill(Color.gray.opacity(0.5)).frame(width: 15, height: 1.5)
                        }
                    }
                }
                .offset(y: 8)
                
                // Eyes
                HStack(spacing: 12) {
                    BenEye(isBlinking: blink, eyeColor: eyeColor, state: state)
                    BenEye(isBlinking: blink, eyeColor: eyeColor, state: state)
                }
                
                // Nose
                Ellipse()
                    .fill(Color(hex: "FFB6C1")) // Light Pink
                    .frame(width: 10, height: 7)
                
                // Mouth
                Path { path in
                    path.move(to: CGPoint(x: -5, y: 0))
                    path.addQuadCurve(to: CGPoint(x: 5, y: 0), control: CGPoint(x: 0, y: 3))
                }
                .stroke(Color.gray.opacity(0.8), lineWidth: 1.5)
                .frame(width: 10, height: 3)
            }
            .offset(y: state == .sleeping ? 5 : -12)
            
            // Accessories
            if state == .invigilator || state == .proud || state == .analytical {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.black)
                    .offset(y: -65)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                breathe = true
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                tailWag = true
            }
        }
        .onReceive(Timer.publish(every: 4.0, on: .main, in: .common).autoconnect()) { _ in
            guard state != .sleeping else { return }
            withAnimation(.easeInOut(duration: 0.1)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { blink = false }
            }
        }
    }
}

struct BenEar: View {
    let catColor: Color
    var body: some View {
        ZStack {
            Triangle()
                .fill(catColor)
                .frame(width: 24, height: 28)
            
            Triangle()
                .fill(Color(hex: "FFB6C1")) // Inner Pink
                .frame(width: 16, height: 18)
                .offset(y: 2)
        }
    }
}

struct BenEye: View {
    let isBlinking: Bool
    let eyeColor: Color
    let state: MascotManager.MascotState
    
    var body: some View {
        ZStack {
            if state == .sleeping || state == .exhausted {
                Rectangle().fill(eyeColor).frame(width: 12, height: 2).offset(y: 2)
            } else if state == .worried {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(eyeColor)
                    .rotationEffect(.degrees(15))
            } else if isBlinking {
                Rectangle().fill(eyeColor).frame(width: 14, height: 2)
            } else {
                Ellipse()
                    .fill(eyeColor)
                    .frame(width: 14, height: 18)
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
