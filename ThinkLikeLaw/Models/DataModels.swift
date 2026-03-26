import Foundation

struct TNACase: Identifiable, Codable {
    var id: String { link }
    let title: String
    let ncn: String
    let link: String
    let date: String
    let court: String
    
    // Optional year for grounding UI
    var year: String? {
        let pattern = "\\d{4}"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: date, options: [], range: NSRange(date.startIndex..., in: date)) {
            return (date as NSString).substring(with: match.range)
        }
        return nil
    }
}

enum EducationLevel: String, CaseIterable, Codable {
    case llb = "LLB"
    case aLevel = "A-Level"
}

enum AIChatMode: String, Codable, CaseIterable {
    case fast = "Fast"
    case normal = "Normal"
    case planning = "Planning"
    
    var icon: String {
        switch self {
        case .fast: return "bolt.fill"
        case .normal: return "brain.fill"
        case .planning: return "map.fill"
        }
    }
    
    var multiplier: Double {
        switch self {
        case .fast: return 1.0
        case .normal: return 1.5
        case .planning: return 3.0
        }
    }
    
    var preferredModel: String {
        switch self {
        case .fast, .normal: return "mistral-small"
        case .planning: return "mistral-large"
        }
    }
}

/**
 * Module — A top-level organizatonal unit (e.g., Contract Law)
 */
struct LawModule: Identifiable, Codable {
    let id: String
    var name: String
    var icon: String
    var description: String
    var archived: Bool
    var examDeadline: Date?
    var createdAt: Date
    var isShared: Bool
    var isDeleted: Bool
    var averageRetention: Double
    
    enum CodingKeys: String, CodingKey {
        case id, name, icon, description, archived, examDeadline, createdAt, isShared, isDeleted, averageRetention
    }
    
    init(id: String, name: String, icon: String, description: String, archived: Bool, examDeadline: Date? = nil, createdAt: Date = Date(), isShared: Bool = false, isDeleted: Bool = false, averageRetention: Double = 100.0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.description = description
        self.archived = archived
        self.examDeadline = examDeadline
        self.createdAt = createdAt
        self.isShared = isShared
        self.isDeleted = isDeleted
        self.averageRetention = averageRetention
    }
    
    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        
        // ID is usually required for logic, but we'll fallback to a random string if totally missing
        id = (try? container?.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        
        name = (try? container?.decodeIfPresent(String.self, forKey: .name)) ?? "Untitled Module"
        icon = (try? container?.decodeIfPresent(String.self, forKey: .icon)) ?? "book.fill"
        description = (try? container?.decodeIfPresent(String.self, forKey: .description)) ?? ""
        archived = (try? container?.decodeIfPresent(Bool.self, forKey: .archived)) ?? false
        examDeadline = try? container?.decodeIfPresent(Date.self, forKey: .examDeadline)
        createdAt = (try? container?.decodeIfPresent(Date.self, forKey: .createdAt)) ?? Date()
        isShared = (try? container?.decodeIfPresent(Bool.self, forKey: .isShared)) ?? false
        isDeleted = (try? container?.decodeIfPresent(Bool.self, forKey: .isDeleted)) ?? false
        averageRetention = (try? container?.decodeIfPresent(Double.self, forKey: .averageRetention)) ?? 100.0
    }

    // Icon mapping from website FA icons to SF Symbols
    var sfSymbol: String {
        switch icon {
        case "fa-file-contract": return "doc.text.fill"
        case "fa-gavel": return "hammer.fill"
        case "fa-scale-balanced": return "scalemass.fill"
        case "fa-bookmark": return "bookmark.fill"
        default: 
            return icon.hasPrefix("fa-") ? "folder.fill" : icon
        }
    }
}

/**
 * LectureNote — Individual study document
 */
struct LectureNote: Identifiable, Codable {
    let id: String
    var title: String
    var content: String
    var moduleId: String?
    var preview: String
    var createdAt: Date
    var lastModified: Date?
    var reviewCount: Int
    var retentionScore: Double
    var drawingData: Data?
    var paperStyle: String?
    var paperColor: String?
    var pdfData: Data?
    var attachmentUrl: String?
    var audioUrl: String?
    var isDeleted: Bool
    var aiHistory: [AIChatMessage] = []
    
    // Spaced Repetition Decay
    var activeRetentionScore: Double {
        // Base score
        let base = retentionScore
        
        // Time since last review/modification
        let referenceDate = lastModified ?? createdAt
        let daysSince = Calendar.current.dateComponents([.day], from: referenceDate, to: Date()).day ?? 0
        
        if daysSince <= 0 { return base }
        
        // Simple linear decay: 1% drop per day of inactivity, capped at a 50% drop
        // So a 100% score decays to 50% after 50 days of not reviewing
        let decay = min(Double(daysSince) * 1.0, 50.0) 
        
        // Ensure it doesn't drop below 0
        return max(base - decay, 0.0)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, moduleId, preview, createdAt, lastModified, reviewCount, retentionScore, drawingData, paperStyle, paperColor, pdfData, attachmentUrl, audioUrl, aiHistory, isDeleted
    }
    
    init(id: String, title: String, content: String, moduleId: String? = nil, preview: String, createdAt: Date = Date(), lastModified: Date? = nil, reviewCount: Int = 0, retentionScore: Double = 1.0, drawingData: Data? = nil, paperStyle: String? = nil, paperColor: String? = nil, pdfData: Data? = nil, attachmentUrl: String? = nil, audioUrl: String? = nil, aiHistory: [AIChatMessage] = [], isDeleted: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.moduleId = moduleId
        self.preview = preview
        self.createdAt = createdAt
        self.lastModified = lastModified
        self.reviewCount = reviewCount
        self.retentionScore = retentionScore
        self.drawingData = drawingData
        self.paperStyle = paperStyle
        self.paperColor = paperColor
        self.pdfData = pdfData
        self.attachmentUrl = attachmentUrl
        self.audioUrl = audioUrl
        self.aiHistory = aiHistory
        self.isDeleted = isDeleted
    }
    
    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        
        id = (try? container?.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? container?.decodeIfPresent(String.self, forKey: .title)) ?? "Untitled Note"
        content = (try? container?.decodeIfPresent(String.self, forKey: .content)) ?? ""
        moduleId = try? container?.decodeIfPresent(String.self, forKey: .moduleId)
        preview = (try? container?.decodeIfPresent(String.self, forKey: .preview)) ?? ""
        createdAt = (try? container?.decodeIfPresent(Date.self, forKey: .createdAt))  ?? Date()
        lastModified = try? container?.decodeIfPresent(Date.self, forKey: .lastModified)
        reviewCount = (try? container?.decodeIfPresent(Int.self, forKey: .reviewCount)) ?? 0
        retentionScore = (try? container?.decodeIfPresent(Double.self, forKey: .retentionScore)) ?? 1.0
        drawingData = try? container?.decodeIfPresent(Data.self, forKey: .drawingData)
        paperStyle = try? container?.decodeIfPresent(String.self, forKey: .paperStyle)
        paperColor = try? container?.decodeIfPresent(String.self, forKey: .paperColor)
        pdfData = try? container?.decodeIfPresent(Data.self, forKey: .pdfData)
        attachmentUrl = try? container?.decodeIfPresent(String.self, forKey: .attachmentUrl)
        audioUrl = try? container?.decodeIfPresent(String.self, forKey: .audioUrl)
        isDeleted = (try? container?.decodeIfPresent(Bool.self, forKey: .isDeleted)) ?? false
        aiHistory = (try? container?.decodeIfPresent([AIChatMessage].self, forKey: .aiHistory)) ?? []
    }
}

struct AIChatMessage: Identifiable, Codable {
    var id: UUID
    let role: String // "user" or "assistant"
    let content: String
    var mode: AIChatMode?
    var thinkingSteps: [String]?
    var isThinking: Bool?
    var factCheckLinks: [TNACase]?
    var cost: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, role, content, mode, thinkingSteps, isThinking, factCheckLinks, cost
    }
    
    init(id: UUID = UUID(), role: String, content: String, mode: AIChatMode? = nil, thinkingSteps: [String]? = nil, isThinking: Bool = false, factCheckLinks: [TNACase]? = nil, cost: Int? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.mode = mode
        self.thinkingSteps = thinkingSteps
        self.isThinking = isThinking
        self.factCheckLinks = factCheckLinks
        self.cost = cost
    }
    
    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        
        if let idString = try? container?.decodeIfPresent(String.self, forKey: .id),
           let uuid = UUID(uuidString: idString) {
            self.id = uuid
        } else if let uuid = try? container?.decodeIfPresent(UUID.self, forKey: .id) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        
        self.role = (try? container?.decodeIfPresent(String.self, forKey: .role)) ?? "user"
        self.content = (try? container?.decodeIfPresent(String.self, forKey: .content)) ?? ""
        self.mode = try? container?.decodeIfPresent(AIChatMode.self, forKey: .mode)
        self.thinkingSteps = try? container?.decodeIfPresent([String].self, forKey: .thinkingSteps)
        self.isThinking = try? container?.decodeIfPresent(Bool.self, forKey: .isThinking)
        self.factCheckLinks = try? container?.decodeIfPresent([TNACase].self, forKey: .factCheckLinks)
        self.cost = try? container?.decodeIfPresent(Int.self, forKey: .cost)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(mode, forKey: .mode)
        try container.encodeIfPresent(thinkingSteps, forKey: .thinkingSteps)
        try container.encodeIfPresent(isThinking, forKey: .isThinking)
        try container.encodeIfPresent(factCheckLinks, forKey: .factCheckLinks)
        try container.encodeIfPresent(cost, forKey: .cost)
    }
}

struct OnlineUser: Identifiable, Codable {
    let id: String
    let fullName: String
    let avatarUrl: String?
    let lastSeenAt: Date
    let broadcastContent: String?
    let broadcastType: String? // e.g., "brief", "highlight"
    
    enum CodingKeys: String, CodingKey {
        case id, fullName, avatarUrl, lastSeenAt, broadcastContent, broadcastType
    }
    
    init(id: String, fullName: String, avatarUrl: String?, lastSeenAt: Date, broadcastContent: String?, broadcastType: String?) {
        self.id = id
        self.fullName = fullName
        self.avatarUrl = avatarUrl
        self.lastSeenAt = lastSeenAt
        self.broadcastContent = broadcastContent
        self.broadcastType = broadcastType
    }
    
    init(from decoder: Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        id = (try? container?.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        fullName = (try? container?.decodeIfPresent(String.self, forKey: .fullName)) ?? "Legal Scholar"
        avatarUrl = try? container?.decodeIfPresent(String.self, forKey: .avatarUrl)
        lastSeenAt = (try? container?.decodeIfPresent(Date.self, forKey: .lastSeenAt)) ?? Date()
        broadcastContent = try? container?.decodeIfPresent(String.self, forKey: .broadcastContent)
        broadcastType = try? container?.decodeIfPresent(String.self, forKey: .broadcastType)
    }
}

struct Deadline: Identifiable, Codable {
    let id: String
    var title: String
    var date: Date
    var moduleId: String?
    var moduleName: String?
    var moduleColor: String?
    var weight: Double
    var priority: Int
    var isNotificationActive: Bool
    var isArchived: Bool
    var isDeleted: Bool
    var createdAt: Date
}

struct StudySession: Identifiable, Codable {
    let id: String
    var date: Date
    var durationMinutes: Int
    var type: String
}

struct Flashcard: Identifiable, Codable {
    let id: String
    var question: String
    var answer: String
    var type: String
    var interval: Double
    var easeFactor: Double
    var repetitions: Int
    var nextReviewDate: Date
    var isLearning: Bool?
    var learningStep: Int?
    var frontImageUrl: String?
    var backImageUrl: String?
    var isDeleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, question, answer, type, interval
        case easeFactor = "ease_factor"
        case repetitions
        case nextReviewDate = "next_review_date"
        case isLearning = "is_learning"
        case learningStep = "learning_step"
        case frontImageUrl = "front_image_url"
        case backImageUrl = "back_image_url"
        case isDeleted = "is_deleted"
    }
}

struct FlashcardSet: Identifiable, Codable {
    let id: String
    var topic: String
    var moduleId: String?
    var moduleName: String?
    var isPublic: Bool
    var isDeleted: Bool
    var createdAt: Date
    var learningSteps: [Int]
    var graduatingInterval: Int
    var easyInterval: Int
    
    enum CodingKeys: String, CodingKey {
        case id, topic
        case moduleId = "module_id"
        case moduleName = "module_name"
        case isPublic = "is_public"
        case isDeleted = "is_deleted"
        case createdAt = "created_at"
        case learningSteps = "learning_steps"
        case graduatingInterval = "graduating_interval"
        case easyInterval = "easy_interval"
    }
}
