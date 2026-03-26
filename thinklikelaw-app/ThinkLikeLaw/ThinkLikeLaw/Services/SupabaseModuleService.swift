import Foundation

/**
 * SupabaseModuleService — Module & Lecture operations extracted from SupabaseManager.
 * Handles CRUD for modules, lectures, file uploads, and sharing.
 */
class SupabaseModuleService {
    static let shared = SupabaseModuleService()
    private let api = SupabaseManager.shared

    private init() {}

    // MARK: - Modules

    func fetchModules() async throws -> [LawModule] {
        return try await api.fetchModules()
    }

    func upsertModule(id: String, name: String, icon: String, description: String, archived: Bool, examDeadline: Date? = nil, isShared: Bool = false, isDeleted: Bool = false) async throws {
        try await api.upsertModule(id: id, name: name, icon: icon, description: description, archived: archived, examDeadline: examDeadline, isShared: isShared, isDeleted: isDeleted)
    }

    func deleteModule(id: String) async throws {
        try await api.deleteModule(id: id)
    }

    // MARK: - Lectures

    func fetchLectures(moduleId: String) async throws -> [LectureNote] {
        return try await api.fetchLectures(moduleId: moduleId)
    }

    func upsertLecture(id: String, moduleId: String, title: String, content: String, preview: String, lastModified: Date = Date(), reviewCount: Int = 0, retentionScore: Double = 100.0, aiHistory: [AIChatMessage] = [], attachmentUrl: String? = nil, drawingData: Data? = nil, paperStyle: String? = nil, paperColor: String? = nil, audioUrl: String? = nil, pdfData: Data? = nil, isDeleted: Bool = false) async throws {
        try await api.upsertLecture(id: id, moduleId: moduleId, title: title, content: content, preview: preview, lastModified: lastModified, reviewCount: reviewCount, retentionScore: retentionScore, aiHistory: aiHistory, attachmentUrl: attachmentUrl, drawingData: drawingData, paperStyle: paperStyle, paperColor: paperColor, audioUrl: audioUrl, pdfData: pdfData, isDeleted: isDeleted)
    }

    func deleteLecture(id: String) async throws {
        try await api.deleteLecture(id: id)
    }

    func fetchLecturesForSharing(moduleId: String, ownerId: String) async throws -> [LectureNote] {
        return try await api.fetchLecturesForSharing(moduleId: moduleId, ownerId: ownerId)
    }

    // MARK: - File Upload

    func uploadFile(data: Data, path: String, mimeType: String) async throws -> String {
        return try await api.uploadFile(data: data, path: path, mimeType: mimeType)
    }
}
