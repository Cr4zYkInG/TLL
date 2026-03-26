import SwiftUI
#if canImport(PencilKit)
import PencilKit
#endif

#if canImport(UIKit) && canImport(PencilKit)
struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var ink: PKInkingTool
    @AppStorage("onlyPencilDraws") var onlyPencilDraws: Bool = true
    @AppStorage("fingerScrollEnabled") var fingerScrollEnabled: Bool = true
    var moduleId: String?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = SensoryCanvasView()
        
        #if os(iOS)
        canvas.applyThinkLikeLawConfig(onlyPencil: onlyPencilDraws, scrollEnabled: fingerScrollEnabled)
        canvas.moduleId = moduleId
        #endif
        
        canvas.drawing = self.canvasView.drawing
        canvas.tool = ink
        
        DispatchQueue.main.async {
            self.canvasView = canvas
        }
        
        let toolPicker = PKToolPicker()
        toolPicker.addObserver(canvas)
        toolPicker.addObserver(context.coordinator)
        context.coordinator.toolPicker = toolPicker
        
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        #if os(iOS)
        uiView.applyThinkLikeLawConfig(onlyPencil: onlyPencilDraws, scrollEnabled: fingerScrollEnabled)
        #endif
        
        if let currentTool = uiView.tool as? PKInkingTool, currentTool != ink {
            uiView.tool = ink
        }
        
        context.coordinator.toolPicker?.selectedTool = ink
    }
    
    class Coordinator: NSObject, PKToolPickerObserver {
        var parent: DrawingCanvasView
        weak var toolPicker: PKToolPicker?
        
        init(_ parent: DrawingCanvasView) {
            self.parent = parent
        }
        
        func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
            if let inkingTool = toolPicker.selectedTool as? PKInkingTool {
                DispatchQueue.main.async {
                    self.parent.ink = inkingTool
                }
            }
        }
    }
}

class SensoryCanvasView: PKCanvasView {
    var moduleId: String?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let touch = touches.first, touch.type == .pencil else { return }
        PencilSensoryEngine.shared.startSensorySession()
        process(touch)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first, touch.type == .pencil else { return }
        process(touch)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        PencilSensoryEngine.shared.stopSensorySession()
        
        if let mid = moduleId {
            DrawingSyncService.shared.syncDrawingDelta(canvasView: self, moduleId: mid)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        PencilSensoryEngine.shared.stopSensorySession()
    }
    
    private func process(_ touch: UITouch) {
        let pressure = touch.force / touch.maximumPossibleForce
        let location = touch.location(in: self)
        let previousLocation = touch.previousLocation(in: self)
        let tilt = touch.altitudeAngle
        
        let dx = location.x - previousLocation.x
        let dy = location.y - previousLocation.y
        let velocity = sqrt(dx*dx + dy*dy) * 60.0
        
        PencilSensoryEngine.shared.update(pressure: pressure, velocity: velocity, tilt: tilt)
    }
}

extension PKCanvasView {
    func applyThinkLikeLawConfig(onlyPencil: Bool, scrollEnabled: Bool) {
        self.drawingPolicy = onlyPencil ? .pencilOnly : .anyInput
        self.isScrollEnabled = scrollEnabled
        self.backgroundColor = .clear
    }
}
#else
// Stub for macOS
struct DrawingCanvasView: View {
    var body: some View {
        VStack {
            Image(systemName: "pencil.slash")
                .font(.largeTitle)
            Text("Drawing is only supported on iPad with Apple Pencil")
                .font(Theme.Fonts.inter(size: 14))
                .foregroundColor(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.surface.opacity(0.8))
    }
}
#endif
