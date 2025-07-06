import Foundation
import SwiftUI

// MARK: - Mind Map Node Models

/// Represents a node in the mind map visualization
struct MindMapNode: Identifiable, Codable, Hashable {
    let id: UUID
    let screenshotId: UUID
    var position: CGPoint
    var velocity: CGVector = .zero
    var radius: CGFloat = 30.0
    var connections: [UUID] = []
    var clusterID: UUID?
    var importance: Double = 1.0
    var isSelected: Bool = false
    var isDragging: Bool = false
    
    // Visual properties
    var color: Color = .blue
    var opacity: Double = 1.0
    var scale: Double = 1.0
    
    // Metadata
    var title: String = ""
    var subtitle: String = ""
    var thumbnailData: Data?
    var entityTypes: [String] = []
    var confidence: Double = 1.0
    
    // Initializer for creating new nodes
    init(screenshotId: UUID, position: CGPoint = .zero) {
        self.id = UUID()
        self.screenshotId = screenshotId
        self.position = position
    }
    
    // Physics properties for force-directed layout
    var mass: Double {
        return importance * 10.0
    }
    
    var attractionStrength: Double {
        return importance * 0.5
    }
}

/// Represents a connection between two nodes
struct MindMapConnection: Identifiable, Codable, Hashable {
    let id: UUID
    let sourceNodeId: UUID
    let targetNodeId: UUID
    let relationshipType: RelationshipType
    let strength: Double
    let confidence: Double
    
    // Visual properties
    var thickness: CGFloat {
        return CGFloat(strength * 5.0 + 1.0)
    }
    
    var opacity: Double {
        return confidence * 0.8 + 0.2
    }
    
    var color: Color {
        return relationshipType.color
    }
    
    // Initializer for creating new connections
    init(sourceNodeId: UUID, targetNodeId: UUID, relationshipType: RelationshipType, strength: Double, confidence: Double) {
        self.id = UUID()
        self.sourceNodeId = sourceNodeId
        self.targetNodeId = targetNodeId
        self.relationshipType = relationshipType
        self.strength = strength
        self.confidence = confidence
    }
}

/// Types of relationships between screenshots
enum RelationshipType: String, CaseIterable, Codable {
    case temporal = "temporal"          // Same time period
    case spatial = "spatial"            // Same location
    case thematic = "thematic"          // Similar content
    case entityBased = "entity_based"   // Shared entities
    case visual = "visual"              // Visual similarity
    case semantic = "semantic"          // Semantic relationship
    
    var displayName: String {
        switch self {
        case .temporal: return "Time-based"
        case .spatial: return "Location-based"
        case .thematic: return "Topic-based"
        case .entityBased: return "Entity-based"
        case .visual: return "Visually similar"
        case .semantic: return "Semantically related"
        }
    }
    
    var color: Color {
        switch self {
        case .temporal: return .green
        case .spatial: return .blue
        case .thematic: return .purple
        case .entityBased: return .orange
        case .visual: return .pink
        case .semantic: return .indigo
        }
    }
    
    var icon: String {
        switch self {
        case .temporal: return "clock"
        case .spatial: return "location"
        case .thematic: return "tag"
        case .entityBased: return "person.2"
        case .visual: return "eye"
        case .semantic: return "brain.head.profile"
        }
    }
}

/// Cluster of related nodes
struct MindMapCluster: Identifiable, Codable {
    let id: UUID
    var nodeIds: [UUID] = []
    var center: CGPoint = .zero
    var radius: CGFloat = 100.0
    var title: String = ""
    var color: Color = .gray
    var importance: Double = 1.0
    
    var boundingRect: CGRect {
        return CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
    }
    
    // Initializer for creating new clusters
    init(title: String = "", center: CGPoint = .zero) {
        self.id = UUID()
        self.title = title
        self.center = center
    }
}

/// Complete mind map data structure
struct MindMapData: Codable {
    var nodes: [UUID: MindMapNode] = [:]
    var connections: [MindMapConnection] = []
    var clusters: [MindMapCluster] = []
    var bounds: CGRect = CGRect(x: -400, y: -400, width: 800, height: 800)
    var lastUpdated: Date = Date()
    
    var nodeArray: [MindMapNode] {
        return Array(nodes.values)
    }
    
    var totalNodes: Int {
        return nodes.count
    }
    
    var totalConnections: Int {
        return connections.count
    }
    
    mutating func addNode(_ node: MindMapNode) {
        nodes[node.id] = node
    }
    
    mutating func removeNode(id: UUID) {
        nodes.removeValue(forKey: id)
        connections.removeAll { $0.sourceNodeId == id || $0.targetNodeId == id }
    }
    
    mutating func addConnection(_ connection: MindMapConnection) {
        // Avoid duplicate connections
        if !connections.contains(where: { 
            ($0.sourceNodeId == connection.sourceNodeId && $0.targetNodeId == connection.targetNodeId) ||
            ($0.sourceNodeId == connection.targetNodeId && $0.targetNodeId == connection.sourceNodeId)
        }) {
            connections.append(connection)
        }
    }
    
    func getConnections(for nodeId: UUID) -> [MindMapConnection] {
        return connections.filter { 
            $0.sourceNodeId == nodeId || $0.targetNodeId == nodeId 
        }
    }
    
    func getConnectedNodes(for nodeId: UUID) -> [MindMapNode] {
        let nodeConnections = getConnections(for: nodeId)
        var connectedNodes: [MindMapNode] = []
        
        for connection in nodeConnections {
            let connectedNodeId = connection.sourceNodeId == nodeId ? 
                connection.targetNodeId : connection.sourceNodeId
            
            if let connectedNode = nodes[connectedNodeId] {
                connectedNodes.append(connectedNode)
            }
        }
        
        return connectedNodes
    }
}

// MARK: - Color Extensions for Codable Support

extension Color: Codable {
    enum CodingKeys: String, CodingKey {
        case red, green, blue, alpha
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let red = try container.decode(Double.self, forKey: .red)
        let green = try container.decode(Double.self, forKey: .green)
        let blue = try container.decode(Double.self, forKey: .blue)
        let alpha = try container.decode(Double.self, forKey: .alpha)
        
        self.init(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // Convert UIColor to get RGBA components
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        try container.encode(Double(red), forKey: .red)
        try container.encode(Double(green), forKey: .green)
        try container.encode(Double(blue), forKey: .blue)
        try container.encode(Double(alpha), forKey: .alpha)
    }
}

// CGVector and CGPoint already conform to Codable in iOS 15+

// MARK: - Physics Constants

struct PhysicsConstants {
    static let defaultRepulsionStrength: Double = 300.0  // Reduced for gentler repulsion
    static let defaultAttractionStrength: Double = 0.08  // Slightly reduced
    static let dampingFactor: Double = 0.9               // Increased for more stability
    static let minimumDistance: Double = 60.0            // Increased minimum distance
    static let maximumDistance: Double = 250.0           // Increased maximum distance
    static let timeStep: Double = 0.016                  // 60fps
    static let convergenceThreshold: Double = 0.05       // Lower threshold for faster convergence
    static let maxIterations: Int = 1000
}