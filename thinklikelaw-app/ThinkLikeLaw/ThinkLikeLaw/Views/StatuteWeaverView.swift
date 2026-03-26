import SwiftUI
import SwiftData

/**
 * StatuteWeaverView — Visual 2D map of statutes and their interpretative case law.
 * Powered by Mistral Large (Premium Feature).
 */
struct StatuteWeaverView: View {
    var hideCloseButton: Bool = false
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let initialTopic: String
    
    @State private var nodes: [WeaverNode] = []
    @State private var edges: [WeaverEdge] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Theme.Colors.bg.ignoresSafeArea()
            
            if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(Theme.Colors.accent)
                        .scaleEffect(1.5)
                    Text("Weaving legal authorities...")
                        .font(Theme.Fonts.outfit(size: 18, weight: .medium))
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(Theme.Fonts.inter(size: 16))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button("Try Again") { weave() }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                // Interactive Canvas
                GeometryReader { geo in
                    ZStack {
                        // Edges (Lines)
                        Path { path in
                            for edge in edges {
                                if let fromNode = nodes.first(where: { $0.id == edge.fromId }),
                                   let toNode = nodes.first(where: { $0.id == edge.toId }) {
                                    path.move(to: fromNode.position)
                                    path.addLine(to: toNode.position)
                                }
                            }
                        }
                        .stroke(Theme.Colors.accent.opacity(0.3), lineWidth: 2)
                        
                        // Nodes
                        ForEach(nodes) { node in
                            NodeView(node: node)
                                .position(node.position)
                                .onTapGesture {
                                    // Handle node tap (e.g., show details)
                                }
                        }
                    }
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                offset = CGSize(
                                    width: offset.width + gesture.translation.width,
                                    height: offset.height + gesture.translation.height
                                )
                            }
                    )
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = value
                            }
                    )
                }
            }
            
            // UI Overlays
            VStack {
                HStack {
                    if !hideCloseButton {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .padding(10)
                                .background(Theme.Colors.surface)
                                .clipShape(Circle())
                                .glassCard()
                        }
                    }
                    Spacer()
                    Text("The Statute Weaver")
                        .font(Theme.Fonts.outfit(size: 20, weight: .bold))
                    Spacer()
                    Button(action: { weave() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Theme.Colors.accent)
                            .padding(10)
                            .background(Theme.Colors.surface)
                            .clipShape(Circle())
                            .glassCard()
                    }
                }
                .padding()
                
                Spacer()
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(Theme.Colors.accent)
                    Text("Nodes show Statutes & Cases. Links represent Judicial Interpretation.")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                .padding()
                .background(Theme.Colors.surface.opacity(0.8))
                .cornerRadius(12)
                .padding(.bottom, 20)
            }
        }
        .onAppear { weave() }
    }
    
    private func weave() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let prompt = "Visualize the relationships for '\(initialTopic)'. Group relevant UK Statutes and landmark cases. Provide a structured 2D map."
                let (response, _) = try await AIService.shared.callAI(tool: .statute_map, content: prompt)
                
                // Parse JSON into nodes and edges
                // Format: { "nodes": [{ "id": "1", "label": "Theft Act", "type": "statute", "x": 100, "y": 100 }], "edges": [{ "from": "1", "to": "2" }] }
                if let data = response.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let nodeArray = json["nodes"] as? [[String: Any]],
                   let edgeArray = json["edges"] as? [[String: Any]] {
                    
                    self.nodes = nodeArray.compactMap { dict in
                        guard let id = dict["id"] as? String,
                              let label = dict["label"] as? String,
                              let type = dict["type"] as? String,
                              let x = dict["x"] as? Double,
                              let y = dict["y"] as? Double else { return nil }
                        return WeaverNode(id: id, label: label, type: WeaverNodeType(rawValue: type) ?? .caseLaw, position: CGPoint(x: x, y: y))
                    }
                    
                    self.edges = edgeArray.compactMap { dict in
                        guard let from = dict["from"] as? String,
                              let to = dict["to"] as? String else { return nil }
                        return WeaverEdge(fromId: from, toId: to)
                    }
                    
                    // Award XP for successful mapping
                    XPService.shared.addXP(.statuteMapCreated)
                }
                
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
}

// MARK: - Components

struct NodeView: View {
    let node: WeaverNode
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: node.type == .statute ? "building.columns.fill" : "doc.plaintext.fill")
                .font(.system(size: 24))
                .foregroundColor(node.type == .statute ? .blue : .orange)
            
            Text(node.label)
                .font(Theme.Fonts.inter(size: 12, weight: .bold))
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .frame(width: 100)
        }
        .padding(12)
        .background(Theme.Colors.surface.opacity(0.8))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.accent.opacity(0.2), lineWidth: 1))
        .glassCard()
    }
}

// MARK: - Models

enum WeaverNodeType: String {
    case statute = "statute"
    case caseLaw = "case"
}

struct WeaverNode: Identifiable {
    let id: String
    let label: String
    let type: WeaverNodeType
    var position: CGPoint
}

struct WeaverEdge {
    let fromId: String
    let toId: String
}
