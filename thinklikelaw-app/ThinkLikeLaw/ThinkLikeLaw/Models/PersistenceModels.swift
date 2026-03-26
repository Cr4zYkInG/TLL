import Foundation
import SwiftData

enum MootDifficulty: String, CaseIterable, Codable {
    case selfRep = "Self-Rep"
    case graduate = "Law Graduate"
    case lawyer = "Seasoned Lawyer"
    case kc = "King's Counsel"
    
    var icon: String {
        switch self {
        case .selfRep: return "person.badge.shield.exclamationmark"
        case .graduate: return "graduationcap.fill"
        case .lawyer: return "briefcase.fill"
        case .kc: return "crown.fill"
        }
    }
    
    var color: String {
        switch self {
        case .selfRep: return "#FF9500" // Orange
        case .graduate: return "#5856D6" // Indigo
        case .lawyer: return "#007AFF" // Blue
        case .kc: return "#AF52DE" // Purple
        }
    }
    
    var unlockLevel: Int {
        switch self {
        case .selfRep: return 1
        case .graduate: return 5
        case .lawyer: return 15
        case .kc: return 30
        }
    }
}

enum MootSide: String, CaseIterable, Codable {
    case claimant = "Claimant"
    case respondent = "Respondent"
    case random = "Random"
}

struct NewsArticle: Identifiable, Codable {
    let id: String
    let title: String
    let url: String
    let source: String
    let category: String
    let snippet: String?
    let imageUrl: String?
    let publishedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, url, source, category, snippet
        case imageUrl = "image_url"
        case publishedAt = "published_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Legal News"
        url = try container.decodeIfPresent(String.self, forKey: .url) ?? ""
        source = try container.decodeIfPresent(String.self, forKey: .source) ?? "ThinkLikeLaw"
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "General"
        snippet = try container.decodeIfPresent(String.self, forKey: .snippet)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        publishedAt = try container.decodeIfPresent(String.self, forKey: .publishedAt) ?? ISO8601DateFormatter().string(from: Date())
    }
}

/**
 * PersistedModule — SwiftData model for Law Modules
 */
@Model
final class PersistedModule {
    @Attribute(.unique) var id: String
    var name: String
    var icon: String
    var desc: String // 'description' is reserved
    var archived: Bool
    var examDeadline: Date?
    var createdAt: Date?
    var isShared: Bool?
    var lastReviewQuality: Double?
    var topicDensity: Double?
    var isDeleted: Bool?
    var displayOrder: Int?
    
    @Relationship(deleteRule: .cascade, inverse: \PersistedNote.module) 
    var notes: [PersistedNote] = []

    @Relationship(deleteRule: .cascade, inverse: \PersistedFlashcardSet.module)
    var flashcardSets: [PersistedFlashcardSet] = []

    init(id: String = UUID().uuidString, name: String, icon: String, desc: String, archived: Bool, examDeadline: Date? = nil, createdAt: Date? = Date(), isShared: Bool = false, isDeleted: Bool = false, displayOrder: Int = 0) {
        self.id = id
        self.name = name
        self.icon = icon
        self.desc = desc
        self.archived = archived
        self.examDeadline = examDeadline
        self.createdAt = createdAt ?? Date()
        self.isShared = isShared
        self.isDeleted = isDeleted
        self.displayOrder = displayOrder
        self.lastReviewQuality = 1.0
        self.topicDensity = 0.5
    }
    
    var averageRetention: Double {
        guard !notes.isEmpty else { return 100.0 }
        let total = notes.reduce(0.0) { $0 + SRSService.shared.calculateNoteRetention(reviewCount: $1.reviewCount, lastReviewedAt: $1.lastReviewedAt) }
        return total / Double(notes.count)
    }
    
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
 * PersistedNote — SwiftData model for Lecture Notes
 */
@Model
final class PersistedNote {
    @Attribute(.unique) var id: String
    var title: String
    var content: String
    var preview: String
    var createdAt: Date?
    var lastModified: Date?
    var reviewCount: Int
    var retentionScore: Double
    var lastReviewedAt: Date?
    var drawingData: Data?
    var paperStyle: String?
    var paperColor: String?
    var moduleId: String?
    var attachmentUrl: String?
    var audioUrl: String?
    var transcriptSegments: Data?
    var pdfData: Data?
    var aiHistory: [AIChatMessage] = []
    var isDeleted: Bool?
    
    var module: PersistedModule?

    init(id: String = UUID().uuidString, title: String, content: String, preview: String, moduleId: String? = nil, createdAt: Date? = Date(), lastModified: Date? = Date(), reviewCount: Int = 0, retentionScore: Double = 1.0, lastReviewedAt: Date? = nil, drawingData: Data? = nil, paperStyle: String = "blank", paperColor: String = "white", attachmentUrl: String? = nil, audioUrl: String? = nil, transcriptSegments: Data? = nil, pdfData: Data? = nil, aiHistory: [AIChatMessage] = [], isDeleted: Bool = false) {
        self.id = id
        self.title = title
        self.content = content
        self.preview = preview
        self.moduleId = moduleId
        self.createdAt = createdAt ?? Date()
        self.lastModified = lastModified ?? Date()
        self.reviewCount = reviewCount
        self.retentionScore = retentionScore
        self.lastReviewedAt = lastReviewedAt
        self.drawingData = drawingData
        self.paperStyle = paperStyle
        self.paperColor = paperColor
        self.attachmentUrl = attachmentUrl
        self.audioUrl = audioUrl
        self.transcriptSegments = transcriptSegments
        self.pdfData = pdfData
        self.aiHistory = aiHistory
        self.isDeleted = isDeleted
    }
}

/**
 * PersistedFlashcardSet — SwiftData model for a deck of flashcards
 */
@Model
final class PersistedFlashcardSet {
    @Attribute(.unique) var id: String
    var topic: String
    var createdAt: Date
    var isPublic: Bool
    
    // Module Mapping for Sync
    var moduleId: String?
    var moduleName: String?
    var isDeleted: Bool? = false
    
    // Deck Options (Anki-style)
    var learningSteps: [Int] = [1, 10] // minutes
    var graduatingInterval: Int = 1 // days
    var easyInterval: Int = 4 // days
    
    var module: PersistedModule?

    @Relationship(deleteRule: .cascade, inverse: \PersistedFlashcard.set)
    var cards: [PersistedFlashcard] = []
    
    init(id: String = UUID().uuidString, topic: String, createdAt: Date = Date(), isPublic: Bool = false, moduleId: String? = nil, moduleName: String? = nil, learningSteps: [Int] = [1, 10], graduatingInterval: Int = 1, easyInterval: Int = 4, isDeleted: Bool = false) {
        self.id = id
        self.topic = topic
        self.createdAt = createdAt
        self.isPublic = isPublic
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.learningSteps = learningSteps
        self.graduatingInterval = graduatingInterval
        self.easyInterval = easyInterval
        self.isDeleted = isDeleted
    }
}

/**
 * PersistedFlashcard — Individual flashcard with SRS metadata
 */
@Model
final class PersistedFlashcard {
    var uuid: String
    var question: String
    var answer: String
    var isDeleted: Bool? = false
    
    // Anki-competitive Metadata
    var type: String? // "basic", "cloze", "image_occlusion"
    var isLearning: Bool?
    var learningStep: Int?
    
    // SRS Metadata
    var interval: Int = 0
    var easeFactor: Double = 2.5
    var repetitions: Int = 0
    var nextReviewDate: Date = Date()
    var lastReviewedAt: Date?
    
    // Rich Media & Markdown
    var frontImageUrl: String?
    var backImageUrl: String?
    var occlusionRectsJson: String? // JSON string of rects for Image Occlusion
    
    var set: PersistedFlashcardSet?
    
    init(uuid: String = UUID().uuidString, 
         question: String, 
         answer: String, 
         type: String = "basic",
         interval: Int = 0, 
         easeFactor: Double = 2.5, 
         repetitions: Int = 0, 
         nextReviewDate: Date = Date(), 
         lastReviewedAt: Date? = nil,
         isLearning: Bool? = true,
         learningStep: Int? = 0,
         frontImageUrl: String? = nil,
         backImageUrl: String? = nil,
         occlusionRectsJson: String? = nil,
         isDeleted: Bool = false) {
        self.uuid = uuid
        self.question = question
        self.answer = answer
        self.type = type
        self.interval = interval
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.nextReviewDate = nextReviewDate
        self.lastReviewedAt = lastReviewedAt
        self.isLearning = isLearning
        self.learningStep = learningStep
        self.frontImageUrl = frontImageUrl
        self.backImageUrl = backImageUrl
        self.occlusionRectsJson = occlusionRectsJson
        self.isDeleted = isDeleted
    }
}

@Model
final class PersistedDeadline {
    @Attribute(.unique) var id: String
    var title: String
    var date: Date
    var moduleId: String?
    var moduleName: String?
    var moduleColor: String? // Hex string
    var weight: Double?
    var priority: Int?
    var isNotificationActive: Bool?
    var isArchived: Bool?
    var isDeleted: Bool?
    var createdAt: Date?
    
    init(id: String? = nil, 
         title: String, 
         date: Date, 
         moduleId: String? = nil, 
         moduleName: String? = nil,
         moduleColor: String? = nil,
         weight: Double = 0.0,
         priority: Int = 1,
         isNotificationActive: Bool = true,
         isDeleted: Bool = false) {
        
        // Use provided ID or generate a new random UUID
        // Supabase expects a valid UUID for the primary key
        self.id = id ?? UUID().uuidString
        
        self.title = title
        self.date = date
        self.moduleId = moduleId
        self.moduleName = moduleName
        self.moduleColor = moduleColor
        self.weight = weight
        self.priority = priority
        self.isNotificationActive = isNotificationActive
        self.isArchived = false
        self.isDeleted = isDeleted
        self.createdAt = Date()
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let deadlineDay = calendar.startOfDay(for: self.date)
        let components = calendar.dateComponents([.day], from: today, to: deadlineDay)
        return components.day ?? 0
    }
    
    var impactScore: Double {
        let days = max(daysRemaining, 1)
        return (weight ?? 0.0) / Double(days)
    }
}

/**
 * PersistedStudySession — Tracks focus time for heatmaps
 */
@Model
final class PersistedStudySession {
    @Attribute(.unique) var id: String
    var date: Date // Use start of day
    var durationMinutes: Int
    var type: String // "notes", "flashcards", "revision"
    
    init(date: Date, durationMinutes: Int, type: String = "general") {
        self.id = "\(Calendar.current.startOfDay(for: date).timeIntervalSince1970)_\(type)"
        self.date = Calendar.current.startOfDay(for: date)
        self.durationMinutes = durationMinutes
        self.type = type
    }
}
/**
 * PersistedChatMessage — SwiftData model for the global flagship AI Chat
 */
@Model
final class PersistedChatMessage {
    @Attribute(.unique) var id: String
    var text: String
    var role: String // "user" or "assistant"
    var timestamp: Date
    var modelUsed: String? // "mistral-small" or "mistral-large"
    var mode: String? // "Fast", "Normal", "Planning"
    var cost: Int? // Credits spent
    
    init(id: String = UUID().uuidString, text: String, role: String, timestamp: Date = Date(), modelUsed: String? = nil, mode: String? = nil, cost: Int? = nil) {
        self.id = id
        self.text = text
        self.role = role
        self.timestamp = timestamp
        self.modelUsed = modelUsed
        self.mode = mode
        self.cost = cost
    }
}

/**
 * PersistedMootResult — Tracks Moot Court outcomes
 */
@Model
final class PersistedMootResult {
    @Attribute(.unique) var id: String
    var date: Date
    var scenario: String
    var difficulty: String // Stored as raw value of MootDifficulty
    var score: Double
    var isWin: Bool
    var transcript: String
    
    init(id: String = UUID().uuidString, date: Date = Date(), scenario: String, difficulty: String, score: Double, isWin: Bool, transcript: String = "") {
        self.id = id
        self.date = date
        self.scenario = scenario
        self.difficulty = difficulty
        self.score = score
        self.isWin = isWin
        self.transcript = transcript
    }
}
