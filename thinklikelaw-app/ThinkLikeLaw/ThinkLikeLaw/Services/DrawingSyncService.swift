import Foundation
#if canImport(PencilKit)
import PencilKit
#endif

#if !os(macOS)
class DrawingSyncService {
    static let shared = DrawingSyncService()
    
    private var lastSyncedStrokeCount: Int = 0
    private var isProcessing = false
    
    private init() {}
    
    /**
     * Synchronize drawing deltas
     * Only broadcasts the new strokes added since the last sync.
     */
    func syncDrawingDelta(canvasView: PKCanvasView, moduleId: String) {
        guard !isProcessing else { return }
        let currentStrokes = canvasView.drawing.strokes
        
        // Only sync if we have more strokes than last time
        guard currentStrokes.count > lastSyncedStrokeCount else { return }
        
        isProcessing = true
        
        let newStrokes = Array(currentStrokes.suffix(currentStrokes.count - lastSyncedStrokeCount))
        let deltaDrawing = PKDrawing(strokes: newStrokes)
        let deltaData = deltaDrawing.dataRepresentation()
        
        // Encode to base64 for transmission via broadcast profile
        let base64Delta = deltaData.base64EncodedString()
        
        CollaborationManager.shared.broadcast(content: base64Delta, type: "drawing_delta")
        
        lastSyncedStrokeCount = currentStrokes.count
        isProcessing = false
        
        print("DrawingSyncService: Broadcasted delta of \(newStrokes.count) strokes.")
    }
    
    /**
     * Apply received delta to local drawing
     */
    func applyDelta(base64Data: String, to canvasView: PKCanvasView) {
        guard let data = Data(base64Encoded: base64Data),
              let deltaDrawing = try? PKDrawing(data: data) else {
            return
        }
        
        DispatchQueue.main.async {
            var currentDrawing = canvasView.drawing
            currentDrawing.append(deltaDrawing)
            canvasView.drawing = currentDrawing
            
            // Sync our local counter so we don't 'broadcast back' what we just received
            self.lastSyncedStrokeCount = canvasView.drawing.strokes.count
        }
    }
    
    func resetSyncState(strokeCount: Int) {
        self.lastSyncedStrokeCount = strokeCount
    }
}
#else
// Stub for macOS compatibility
class DrawingSyncService {
    static let shared = DrawingSyncService()
    private init() {}
    func syncDrawingDelta(canvasView: Any, moduleId: String) {}
    func applyDelta(base64Data: String, to canvasView: Any) {}
    func resetSyncState(strokeCount: Int) {}
}
#endif
