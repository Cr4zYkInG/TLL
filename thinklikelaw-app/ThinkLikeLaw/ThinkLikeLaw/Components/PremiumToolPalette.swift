import SwiftUI
#if canImport(PencilKit)
import PencilKit
#endif

#if canImport(PencilKit) && canImport(UIKit)
struct PremiumToolPalette: View {
    @Binding var ink: PKInkingTool
    @Binding var isDrawingMode: Bool
    @State private var showSettings = false
    
    let tools: [InkTool] = [
        InkTool(type: .pen, icon: "paintbrush.pointed.fill", label: "Fountain"),
        InkTool(type: .pencil, icon: "pencil.tip", label: "Pencil"),
        InkTool(type: .marker, icon: "highlighter", label: "Chisel")
    ]
    
    var body: some View {
        HStack(spacing: 20) {
            // Mode Toggle
            Button(action: { 
                withAnimation(.spring()) { isDrawingMode.toggle() }
                Theme.HapticFeedback.success()
            }) {
                Image(systemName: isDrawingMode ? "pencil.and.outline" : "keyboard")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(isDrawingMode ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(isDrawingMode ? Theme.Colors.accent.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }
            
            Divider().frame(height: 24)
            
            // Tool Selection
            ForEach(tools) { tool in
                PremiumToolButton(tool: tool, currentInk: $ink, isDrawingMode: isDrawingMode)
            }
            
            Divider().frame(height: 24)
            
            // Color Selection (Premium Wells)
            HStack(spacing: 12) {
                ColorWell(color: .black, currentInk: $ink)
                ColorWell(color: Color(hex: "003366"), currentInk: $ink) // Deep Legal Blue
                ColorWell(color: Color(hex: "8B0000"), currentInk: $ink) // Oxblood Red
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Theme.Colors.surface.opacity(0.8))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.Colors.glassBorder, lineWidth: 1)
        )
    }
}

struct InkTool: Identifiable {
    var id: String { label }
    let type: PKInkingTool.InkType
    let icon: String
    let label: String
}

struct PremiumToolButton: View {
    let tool: InkTool
    @Binding var currentInk: PKInkingTool
    let isDrawingMode: Bool
    @State private var showDetail = false
    
    var isSelected: Bool {
        isDrawingMode && currentInk.inkType == tool.type
    }
    
    var body: some View {
        Button(action: {
            if isSelected {
                showDetail.toggle()
            } else {
                currentInk = PKInkingTool(tool.type, color: currentInk.color, width: currentInk.width)
                Theme.HapticFeedback.medium()
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: tool.icon)
                    .font(.system(size: 18, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? Theme.Colors.accent : Theme.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(isSelected ? Theme.Colors.accent.opacity(0.1) : Color.clear)
                    .clipShape(Circle())
            }
            .frame(width: 40)
        }
        .popover(isPresented: $showDetail) {
            ToolSettingsView(inkingTool: $currentInk)
                .presentationCompactAdaptation(.popover)
        }
    }
}

struct ToolSettingsView: View {
    @Binding var inkingTool: PKInkingTool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Text(toolName)
                    .font(Theme.Fonts.outfit(size: 16, weight: .bold))
                Spacer()
                Image(systemName: "seal.fill")
                    .foregroundColor(Theme.Colors.accent)
            }
            
            // Stroke Preview
            VStack(spacing: 8) {
                Text("Stroke Preview")
                    .font(Theme.Fonts.inter(size: 10, weight: .bold))
                    .foregroundColor(Theme.Colors.textSecondary.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.Colors.bg.opacity(0.5))
                        .frame(height: 60)
                    
                    StrokePreview(inkingTool: inkingTool)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.Colors.glassBorder, lineWidth: 1)
                )
            }
            
            // Thickness
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Nib Thickness")
                        .font(Theme.Fonts.inter(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(String(format: "%.1f", inkingTool.width))mm")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(Theme.Colors.accent)
                }
                
                Slider(value: Binding(
                    get: { inkingTool.width },
                    set: { inkingTool.width = $0 }
                ), in: 0.5...40)
                .accentColor(Theme.Colors.accent)
            }
            
            // Fountain Logic
            if inkingTool.inkType == .pen {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Fountain Nib Presets")
                        .font(Theme.Fonts.inter(size: 12, weight: .semibold))
                    
                    HStack(spacing: 8) {
                        NibPresetButton(label: "EF", sub: "Extra Fine", width: 1.5, currentInkingTool: $inkingTool)
                        NibPresetButton(label: "F", sub: "Fine", width: 3.0, currentInkingTool: $inkingTool)
                        NibPresetButton(label: "M", sub: "Medium", width: 5.0, currentInkingTool: $inkingTool)
                        NibPresetButton(label: "B", sub: "Bold", width: 8.0, currentInkingTool: $inkingTool)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ink Flow Characteristics")
                            .font(Theme.Fonts.inter(size: 10, weight: .bold))
                            .foregroundColor(Theme.Colors.textSecondary.opacity(0.8))
                        
                        HStack {
                            DetailChip(label: "Pressure Sensitive", isActive: true)
                            DetailChip(label: "Velocity Damping", isActive: true)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 300)
    }
    
    private var toolName: String {
        switch inkingTool.inkType {
        case .pen: return "Fountain Pen"
        case .pencil: return "Pencil"
        case .marker: return "Chisel Highlighter"
        case .monoline: return "Monoline Pen"
        case .watercolor: return "Watercolor Brush"
        case .crayon: return "Crayon"
        default: return "Bespoke Tool"
        }
    }
}

struct NibPresetButton: View {
    let label: String
    let sub: String
    let width: CGFloat
    @Binding var currentInkingTool: PKInkingTool
    
    var isSelected: Bool { abs(currentInkingTool.width - width) < 0.1 }
    
    var body: some View {
        Button(action: {
            currentInkingTool.width = width
            Theme.HapticFeedback.success()
        }) {
            VStack(spacing: 2) {
                Text(label)
                    .font(Theme.Fonts.outfit(size: 14, weight: .bold))
                Text(sub)
                    .font(.system(size: 7, weight: .medium))
                    .opacity(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Theme.Colors.accent.opacity(0.1) : Color.clear)
            .foregroundColor(isSelected ? Theme.Colors.accent : Theme.Colors.textSecondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Theme.Colors.accent.opacity(0.3) : Theme.Colors.glassBorder, lineWidth: 1)
            )
        }
    }
}

struct StrokePreview: View {
    let inkingTool: PKInkingTool
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 20, y: 30))
            path.addCurve(to: CGPoint(x: 220, y: 30), 
                         control1: CGPoint(x: 80, y: 10), 
                         control2: CGPoint(x: 160, y: 50))
        }
        .stroke(strokeColor, style: StrokeStyle(lineWidth: inkingTool.width, lineCap: .round, lineJoin: .round))
        .padding(.horizontal, 20)
    }
    
    var strokeColor: Color {
        // If the color is fixed black and we are in dark mode, invert it for visibility
        if inkingTool.color == PlatformColor.black {
            return colorScheme == .dark ? .white : .black
        }
        return Color(inkingTool.color)
    }
}

struct DetailChip: View {
    let label: String
    let isActive: Bool
    
    var body: some View {
        Text(label)
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.Colors.accent.opacity(0.1))
            .foregroundColor(Theme.Colors.accent)
            .cornerRadius(4)
    }
}

struct ColorWell: View {
    let color: Color
    @Binding var currentInk: PKInkingTool
    
    var isSelected: Bool {
        currentInk.color == PlatformColor(color)
    }
    
    var body: some View {
        Button(action: {
            currentInk = PKInkingTool(currentInk.inkType, color: PlatformColor(color), width: currentInk.width)
            Theme.HapticFeedback.medium()
        }) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Theme.Colors.accent, lineWidth: 2)
                        .opacity(isSelected ? 1 : 0)
                )
                .shadow(color: color.opacity(0.3), radius: 4, y: 2)
        }
    }
}
#else
// Stub for macOS
struct PremiumToolPalette: View {
    var body: some View {
        EmptyView()
    }
}
#endif
