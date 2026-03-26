import Foundation

/**
 * SupabaseManager — Networking Layer for ThinkLikeLaw iOS
 * Handles communication with the Supabase backend.
 */
class SupabaseManager {
    static let shared = SupabaseManager()
    
    private let supabaseUrl = "https://oxlpmgnytsvdjcibtdmb.supabase.co"
    private let supabaseKey = "sb_publishable_hR5BbCbWqj0V7sZP6lpDjg_sMhNg84A"
    
    private var authToken: String? {
        get { UserDefaults.standard.string(forKey: "supabase_auth_token") }
        set { UserDefaults.standard.set(newValue, forKey: "supabase_auth_token") }
    }
    
    private var refreshToken: String? {
        get { UserDefaults.standard.string(forKey: "supabase_refresh_token") }
        set { UserDefaults.standard.set(newValue, forKey: "supabase_refresh_token") }
    }
    
    private init() {}
    
    // --- Authentication ---
    
    func signIn(email: String, password: String) async throws -> String {
        let url = URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=password")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SupabaseAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let token = json?["access_token"] as? String ?? ""
        let refresh = json?["refresh_token"] as? String ?? ""
        let userId = (json?["user"] as? [String: Any])?["id"] as? String ?? ""
        
        self.authToken = token
        self.refreshToken = refresh
        UserDefaults.standard.set(userId, forKey: "supabase_user_id")
        return token
    }
    
    func signInWithIdToken(provider: String, idToken: String, nonce: String? = nil) async throws -> String {
        let url = URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=id_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "provider": provider,
            "id_token": idToken
        ]
        if let nonce = nonce { body["nonce"] = nonce }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SupabaseAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "\(provider) sign-in failed"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let token = json?["access_token"] as? String ?? ""
        let refresh = json?["refresh_token"] as? String ?? ""
        let userId = (json?["user"] as? [String: Any])?["id"] as? String ?? ""
        
        self.authToken = token
        self.refreshToken = refresh
        UserDefaults.standard.set(userId, forKey: "supabase_user_id")
        return token
    }
    
    func signUp(email: String, password: String, metadata: [String: Any]) async throws -> String {
        let url = URL(string: "\(supabaseUrl)/auth/v1/signup")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["email": email, "password": password, "data": metadata]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SupabaseAuth", code: 400, userInfo: [NSLocalizedDescriptionKey: "Signup failed"])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return json?["id"] as? String ?? "user_pending_verification"
    }
    
    func refreshSession() async throws -> String {
        guard let refresh = refreshToken else {
            throw NSError(domain: "SupabaseAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "No refresh token available"])
        }
        
        let url = URL(string: "\(supabaseUrl)/auth/v1/token?grant_type=refresh_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["refresh_token": refresh]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            // If refresh fails, clear everything
            self.authToken = nil
            self.refreshToken = nil
            UserDefaults.standard.removeObject(forKey: "supabase_user_id")
            throw NSError(domain: "SupabaseAuth", code: 401, userInfo: [NSLocalizedDescriptionKey: "Session expired. Please log in again."])
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let newToken = json?["access_token"] as? String ?? ""
        let newRefresh = json?["refresh_token"] as? String ?? ""
        
        self.authToken = newToken
        self.refreshToken = newRefresh
        return newToken
    }
    
    private func authorizedRequest(_ url: URL, method: String = "GET", body: Data? = nil, contentType: String? = "application/json", prefer: String? = nil) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        if let body = body {
            request.httpBody = body
            if let contentType = contentType {
                request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            }
        }
        if let prefer = prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            print("Supabase: 401 detected, attempting session refresh...")
            do {
                _ = try await refreshSession()
                // Retry once
                var retryRequest = request
                retryRequest.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
                return try await URLSession.shared.data(for: retryRequest)
            } catch {
                print("Supabase: Session refresh failed: \(error)")
                throw error
            }
        }
        return (data, response)
    }
    
    // Convenience for JSON bodies
    private func authorizedRequest(_ url: URL, method: String = "GET", jsonBody: [String: Any]? = nil, prefer: String? = nil) async throws -> (Data, URLResponse) {
        let data = jsonBody != nil ? try? JSONSerialization.data(withJSONObject: jsonBody!) : nil
        return try await authorizedRequest(url, method: method, body: data, contentType: "application/json", prefer: prefer)
    }
    
    // --- Profiles ---
    
    func getUserProfile(userId: String) async throws -> [String: Any] {
        let url = URL(string: "\(supabaseUrl)/rest/v1/profiles?id=eq.\(userId)&select=*")!
        let (data, _) = try await authorizedRequest(url)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return json?.first ?? [:]
    }
    
    func getUserCredits(userId: String) async throws -> Int {
        let url = URL(string: "\(supabaseUrl)/rest/v1/user_credits?user_id=eq.\(userId)&select=credits")!
        let (data, _) = try await authorizedRequest(url)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return json?.first?["credits"] as? Int ?? 0
    }
    
    
    func fetchActiveUsers(moduleId: String) async throws -> [OnlineUser] {
        // Find users who have been seen in the last 5 minutes and are in this module
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let formatter = ISO8601DateFormatter()
        let timeString = formatter.string(from: fiveMinutesAgo)
        
        let url = URL(string: "\(supabaseUrl)/rest/v1/profiles?active_module_id=eq.\(moduleId)&last_seen_at=gt.\(timeString)&select=id,full_name,avatar_url,last_seen_at,broadcast_content,broadcast_type")!
        
        let (data, response) = try await authorizedRequest(url, method: "GET")
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SupabaseData", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch active users"])
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        struct ProfileResponse: Codable {
            let id: String
            let full_name: String?
            let avatar_url: String?
            let last_seen_at: Date?
            let broadcast_content: String?
            let broadcast_type: String?
        }
        
        let profiles = try decoder.decode([ProfileResponse].self, from: data)
        return profiles.map { 
            OnlineUser(
                id: $0.id, 
                fullName: $0.full_name ?? "Legal Scholar", 
                avatarUrl: $0.avatar_url, 
                lastSeenAt: $0.last_seen_at ?? Date(), 
                broadcastContent: $0.broadcast_content,
                broadcastType: $0.broadcast_type
            )
        }
    }
    
    // --- Modules & Lectures ---
    
    func fetchModules() async throws -> [LawModule] {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return [] }
        let url = URL(string: "\(supabaseUrl)/rest/v1/user_modules?user_id=eq.\(userId)&is_deleted=eq.false&select=*&order=created_at.desc")!
        let (data, response) = try await authorizedRequest(url)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            print("Supabase Module Sync Error [\(httpResponse.statusCode)]: \(errorBody)")
            throw NSError(domain: "SupabaseData", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch modules: \(errorBody)"])
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([LawModule].self, from: data)
    }
    
    func upsertModule(id: String, name: String, icon: String, description: String, archived: Bool, examDeadline: Date? = nil, isShared: Bool = false, isDeleted: Bool = false) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return }
        let url = URL(string: "\(supabaseUrl)/rest/v1/user_modules")!
        
        var body: [String: Any] = [
            "id": id,
            "user_id": userId,
            "name": name,
            "icon": icon,
            "description": description,
            "archived": archived,
            "is_shared": isShared,
            "is_deleted": isDeleted
        ]
        
        if let deadline = examDeadline {
            body["exam_deadline"] = ISO8601DateFormatter().string(from: deadline)
        }
        
        let (data, response) = try await authorizedRequest(url, method: "POST", jsonBody: body, prefer: "resolution=merge-duplicates")
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            print("Supabase Module Insert Error [\(httpResponse.statusCode)]: \(errorBody)")
            throw NSError(domain: "SupabaseData", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to upsert module: \(errorBody)"])
        }
    }
    
    func upsertLecture(id: String, moduleId: String, title: String, content: String, preview: String, lastModified: Date = Date(), reviewCount: Int = 0, retentionScore: Double = 100.0, aiHistory: [AIChatMessage] = [], attachmentUrl: String? = nil, drawingData: Data? = nil, paperStyle: String? = nil, paperColor: String? = nil, audioUrl: String? = nil, pdfData: Data? = nil, isDeleted: Bool = false) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return }
        let url = URL(string: "\(supabaseUrl)/rest/v1/lectures")!
        
        var body: [String: Any] = [
            "id": id,
            "user_id": userId,
            "module_id": moduleId,
            "title": title,
            "content": content,
            "preview": preview,
            "review_count": reviewCount,
            "retention_score": retentionScore,
            "is_deleted": isDeleted,
            "last_modified": ISO8601DateFormatter().string(from: lastModified)
        ]
        
        // Encode AI History
        if let historyData = try? JSONEncoder().encode(aiHistory),
           let historyJson = try? JSONSerialization.jsonObject(with: historyData) {
            body["ai_history"] = historyJson
        }
        
        if let attachmentUrl = attachmentUrl { body["attachment_url"] = attachmentUrl }
        if let drawingData = drawingData { body["drawing_data"] = drawingData.base64EncodedString() }
        if let paperStyle = paperStyle { body["paper_style"] = paperStyle }
        if let paperColor = paperColor { body["paper_color"] = paperColor }
        if let audioUrl = audioUrl { body["audio_url"] = audioUrl }
        if let pdfData = pdfData { body["pdf_data"] = pdfData.base64EncodedString() }
        
        let (data, response) = try await authorizedRequest(url, method: "POST", jsonBody: body, prefer: "resolution=merge-duplicates")
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            print("Supabase Lecture Insert Error [\(httpResponse.statusCode)]: \(errorBody)")
            throw NSError(domain: "SupabaseData", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to upsert lecture: \(errorBody)"])
        }
    }
    
    func deleteLecture(id: String) async throws {
        let url = URL(string: "\(supabaseUrl)/rest/v1/lectures?id=eq.\(id)")!
        let (_, response) = try await authorizedRequest(url, method: "PATCH", jsonBody: ["is_deleted": true])
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw NSError(domain: "SupabaseData", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to soft delete lecture"])
        }
    }
    
    // --- Deadlines ---
    
    func fetchDeadlines() async throws -> [Deadline] {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return [] }
        let url = URL(string: "\(supabaseUrl)/rest/v1/deadlines?user_id=eq.\(userId)&select=*&order=date.asc")!
        let (data, response) = try await authorizedRequest(url)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            print("Supabase Deadline Sync Error [\(httpResponse.statusCode)]: \(errorBody)")
            throw NSError(domain: "SupabaseData", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch deadlines: \(errorBody)"])
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        // Map raw data to plain Deadline DTO
        struct RawDeadline: Codable {
            let id: String
            let userId: String?
            let title: String?
            let date: Date?
            let moduleId: String?
            let moduleName: String?
            let moduleColor: String?
            let weight: Double?
            let priority: Int?
            let isNotificationActive: Bool?
            let isArchived: Bool?
            let isDeleted: Bool?
            let createdAt: Date?
            
            enum CodingKeys: String, CodingKey {
                case id, userId, title, date, moduleId, moduleName, moduleColor, weight, priority, isNotificationActive, isArchived, isDeleted, createdAt
            }
        }
        
        let raws = try decoder.decode([RawDeadline].self, from: data)
        return raws.map { r in
            Deadline(
                id: r.id,
                title: r.title ?? "Untitled Deadline",
                date: r.date ?? Date(),
                moduleId: r.moduleId,
                moduleName: r.moduleName,
                moduleColor: r.moduleColor,
                weight: r.weight ?? 0.0,
                priority: r.priority ?? 1,
                isNotificationActive: r.isNotificationActive ?? true,
                isArchived: r.isArchived ?? false,
                isDeleted: r.isDeleted ?? false,
                createdAt: r.createdAt ?? Date()
            )
        }
    }
    
    func upsertDeadline(id: String, title: String, date: Date, moduleId: String?, moduleName: String?, moduleColor: String?, weight: Double, priority: Int, isNotificationActive: Bool, isArchived: Bool, isDeleted: Bool = false) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return }
        let url = URL(string: "\(supabaseUrl)/rest/v1/deadlines")!
        
        var body: [String: Any] = [
            "id": id,
            "user_id": userId,
            "title": title,
            "date": ISO8601DateFormatter().string(from: date),
            "weight": weight,
            "priority": priority,
            "is_notification_active": isNotificationActive,
            "is_archived": isArchived,
            "is_deleted": isDeleted
        ]
        
        if let moduleId = moduleId { body["module_id"] = moduleId }
        if let moduleName = moduleName { body["module_name"] = moduleName }
        if let moduleColor = moduleColor { body["module_color"] = moduleColor }
        
        let (data, response) = try await authorizedRequest(url, method: "POST", jsonBody: body, prefer: "resolution=merge-duplicates")
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            print("Supabase Deadline Insert Error [\(httpResponse.statusCode)]: \(errorBody)")
            throw NSError(domain: "SupabaseData", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to upsert deadline: \(errorBody)"])
        }
    }
    
    func deleteDeadline(id: String) async throws {
        let url = URL(string: "\(supabaseUrl)/rest/v1/deadlines?id=eq.\(id)")!
        let (data, response) = try await authorizedRequest(url, method: "DELETE")
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            print("Supabase Deadline Delete Error [\(httpResponse.statusCode)]: \(errorBody)")
            throw NSError(domain: "SupabaseData", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete deadline: \(errorBody)"])
        }
    }
    
    func uploadFile(data: Data, path: String, mimeType: String) async throws -> String {
        // path should be e.g. "lectures/note_id.pdf"
        let url = URL(string: "\(supabaseUrl)/storage/v1/object/attachments/\(path)")!
        
        let (responseData, response) = try await authorizedRequest(url, method: "POST", body: data, contentType: mimeType)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any]
            let message = errorJson?["message"] as? String ?? "Upload failed"
            throw NSError(domain: "SupabaseStorage", code: 500, userInfo: [NSLocalizedDescriptionKey: message])
        }
        
        // Return the public URL (assuming the bucket 'attachments' is public)
        return "\(supabaseUrl)/storage/v1/object/public/attachments/\(path)"
    }
    
    func fetchLectures(moduleId: String) async throws -> [LectureNote] {
        print("DEBUG_CRASH: fetchLectures (Supabase) started for module: \(moduleId)")
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { 
            print("DEBUG_CRASH: fetchLectures failed - no userId")
            return [] 
        }
        let url = URL(string: "\(supabaseUrl)/rest/v1/lectures?user_id=eq.\(userId)&module_id=eq.\(moduleId)&is_deleted=eq.false&select=*&order=created_at.desc")!
        let (data, response) = try await authorizedRequest(url)
        
        print("DEBUG_CRASH: fetchLectures (Supabase) got data: \(data.count) bytes")
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            print("DEBUG_CRASH: fetchLectures (Supabase) HTTP Error: \((response as? HTTPURLResponse)?.statusCode ?? 0)")
            throw NSError(domain: "SupabaseData", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch lectures"])
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        do {
            let notes = try decoder.decode([LectureNote].self, from: data)
            print("DEBUG_CRASH: fetchLectures (Supabase) successfully decoded \(notes.count) notes")
            return notes
        } catch {
            print("DEBUG_CRASH: fetchLectures (Supabase) DECODING ERROR: \(error)")
            throw error
        }
    }
    
    /**
     * Fetch lectures for a specific module owned by ANY user (used for sharing/joining)
     */
    func fetchLecturesForSharing(moduleId: String, ownerId: String) async throws -> [LectureNote] {
        let url = URL(string: "\(supabaseUrl)/rest/v1/lectures?user_id=eq.\(ownerId)&module_id=eq.\(moduleId)&select=*&order=created_at.desc")!
        let (data, response) = try await authorizedRequest(url)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SupabaseData", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch shared lectures"])
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([LectureNote].self, from: data)
    }
    
    // --- News ---
    
    func fetchNewsArticles(category: String) async throws -> [NewsArticle] {
        let baseUrl = "\(supabaseUrl)/rest/v1/news_articles?select=*&order=published_at.desc&limit=30"
        let finalUrl = category == "All" ? baseUrl : "\(baseUrl)&category=eq.\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category)"
        
        let (data, response) = try await authorizedRequest(URL(string: finalUrl)!)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SupabaseData", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch news"])
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([NewsArticle].self, from: data)
    }
    
    // --- Community Hub ---

    func fetchCommunityFeed(type: String = "all") async throws -> [[String: Any]] {
        // This combines notes and flashcards, matching CloudData.js logic
        var items: [[String: Any]] = []
        
        // 1. Fetch Notes (Lectures)
        if type == "all" || type == "notes" {
            let url = URL(string: "\(supabaseUrl)/rest/v1/lectures?is_public=eq.true&select=id,user_id,title,content,module_id,upvotes,created_at,user_modules(name),profiles(leaderboard_username,university)&order=created_at.desc&limit=50")!
            let (data, _) = try await authorizedRequest(url)
            if let notes = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for note in notes {
                    // Handle profiles join (could be object or array of one)
                    let profileRaw = note["profiles"]
                    let profile: [String: Any]
                    if let pObj = profileRaw as? [String: Any] {
                        profile = pObj
                    } else if let pArr = profileRaw as? [[String: Any]], let first = pArr.first {
                        profile = first
                    } else {
                        profile = [:]
                    }
                    
                    let moduleName = (note["user_modules"] as? [String: Any])?["name"] as? String ?? (note["module_id"] as? String ?? "General Law")
                    
                    items.append([
                        "id": note["id"] ?? "",
                        "type": "note",
                        "title": note["title"] ?? "Untitled Note",
                        "module_name": moduleName,
                        "preview": (note["content"] as? String)?.prefix(150).description ?? "",
                        "author_name": (profile["leaderboard_username"] as? String).map { "@\($0)" } ?? "Anonymous",
                        "university": profile["university"] ?? "",
                        "upvotes": note["upvotes"] ?? 0,
                        "created": note["created_at"] ?? ""
                    ])
                }
            }
        }
        
        // 2. Fetch Flashcards
        if type == "all" || type == "flashcards" {
            let url = URL(string: "\(supabaseUrl)/rest/v1/user_flashcards?is_public=eq.true&select=id,user_id,topic,cards,upvotes,created_at,profiles(leaderboard_username,university)&order=created_at.desc&limit=50")!
            let (data, _) = try await authorizedRequest(url)
            if let decks = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                for deck in decks {
                    let profileRaw = deck["profiles"]
                    let profile: [String: Any]
                    if let pObj = profileRaw as? [String: Any] {
                        profile = pObj
                    } else if let pArr = profileRaw as? [[String: Any]], let first = pArr.first {
                        profile = first
                    } else {
                        profile = [:]
                    }

                    items.append([
                        "id": deck["id"] ?? "",
                        "type": "flashcard",
                        "title": deck["topic"] ?? "Flashcard Deck",
                        "module_name": "", 
                        "preview": "Shared Flashcard Deck",
                        "author_name": (profile["leaderboard_username"] as? String).map { "@\($0)" } ?? "Anonymous",
                        "university": profile["university"] ?? "",
                        "upvotes": deck["upvotes"] ?? 0,
                        "created": deck["created_at"] ?? ""
                    ])
                }
            }
        }
        
        return items.sorted { a, b in
            let d1 = (a["created"] as? String) ?? ""
            let d2 = (b["created"] as? String) ?? ""
            return d1 > d2
        }
    }
    
    func forkItem(itemId: String, type: String) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return }
        
        let table = type == "note" ? "lectures" : "user_flashcards"
        let url = URL(string: "\(supabaseUrl)/rest/v1/\(table)?id=eq.\(itemId)&select=*")!
        let (data, _) = try await authorizedRequest(url)
        guard var item = (try JSONSerialization.jsonObject(with: data) as? [[String: Any]])?.first else { throw NSError(domain: "Supabase", code: 404, userInfo: nil) }
        
        // 1. Ensure "My Forks" module exists for notes
        var targetModuleId: String? = nil
        if type == "note" {
            // Check if module exists
            let modUrl = URL(string: "\(supabaseUrl)/rest/v1/user_modules?user_id=eq.\(userId)&name=eq.My%20Forks&select=id")!
            let (modData, _) = try await authorizedRequest(modUrl)
            let mods = try JSONSerialization.jsonObject(with: modData) as? [[String: Any]]
            
            if let first = mods?.first, let id = first["id"] as? String {
                targetModuleId = id
            } else {
                // Create it
                let body = ["user_id": userId, "name": "My Forks", "icon": "arrow.triangle.branch", "description": "Your forked notes."]
                let (cData, _) = try await authorizedRequest(URL(string: "\(supabaseUrl)/rest/v1/user_modules")!, method: "POST", jsonBody: body, prefer: "return=representation")
                let cJson = try JSONSerialization.jsonObject(with: cData) as? [[String: Any]]
                targetModuleId = cJson?.first?["id"] as? String
            }
        }

        // 2. Modify fields for the new fork
        item["id"] = UUID().uuidString.lowercased()
        item["user_id"] = userId
        item["is_public"] = false
        item["upvotes"] = 0
        item["created_at"] = ISO8601DateFormatter().string(from: Date())
        if let targetModuleId = targetModuleId {
            item["module_id"] = targetModuleId
        }
        
        // 3. Upsert back to the same table
        let urlFork = URL(string: "\(supabaseUrl)/rest/v1/\(table)")!
        _ = try await authorizedRequest(urlFork, method: "POST", jsonBody: item)
    }

    func upsertFlashcardSet(
        id: String, 
        topic: String, 
        cards: [[String: Any]], 
        moduleId: String? = nil, 
        isPublic: Bool = false,
        learningSteps: [Int] = [1, 10],
        graduatingInterval: Int = 1,
        easyInterval: Int = 4
    ) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return }
        let url = URL(string: "\(supabaseUrl)/rest/v1/user_flashcards")!
        
        var body: [String: Any] = [
            "id": id,
            "user_id": userId,
            "topic": topic,
            "cards": cards,
            "is_public": isPublic,
            "learning_steps": "{" + learningSteps.map(String.init).joined(separator: ",") + "}",
            "graduating_interval": graduatingInterval,
            "easy_interval": easyInterval,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let moduleId = moduleId {
            body["module_id"] = moduleId
        }
        
        let (data, response) = try await authorizedRequest(url, method: "POST", jsonBody: body, prefer: "resolution=merge-duplicates")
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            print("Supabase Flashcard Sync Error [\(httpResponse.statusCode)]: \(errorBody)")
            throw NSError(domain: "SupabaseData", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to upsert flashcard: \(errorBody)"])
        }
    }

    // --- User Metrics & XP ---

    func updateXP(total: Int) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return }
        let url = URL(string: "\(supabaseUrl)/rest/v1/user_metrics?user_id=eq.\(userId)")!
        
        // We use total_xp for Ultra-Elite career metrics
        _ = try await authorizedRequest(url, method: "PATCH", jsonBody: ["total_xp": total])
    }

    // --- Flashcards ---

    func fetchFlashcardSets() async throws -> [FlashcardSet] {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return [] }
        let url = URL(string: "\(supabaseUrl)/rest/v1/user_flashcard_sets?user_id=eq.\(userId)&is_deleted=eq.false&select=*&order=created_at.desc")!
        let (data, _) = try await authorizedRequest(url)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys // Use custom CodingKeys
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([FlashcardSet].self, from: data)
    }

    func fetchFlashcards(setId: String) async throws -> [Flashcard] {
        let url = URL(string: "\(supabaseUrl)/rest/v1/user_flashcards?set_id=eq.\(setId)&is_deleted=eq.false&select=*")!
        let (data, _) = try await authorizedRequest(url)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys // Use custom CodingKeys
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Flashcard].self, from: data)
    }

    // --- Leaderboard ---

    func fetchLeaderboard() async throws -> [[String: Any]] {
        // Join profiles with user_metrics to get total XP for Career Rankings
        let url = URL(string: "\(supabaseUrl)/rest/v1/user_metrics?select=total_xp,lifetime_study_time,streak,profiles(first_name,last_name,university)&order=total_xp.desc&limit=20")!
        var request = URLRequest(url: url)
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }
    
    func fetchUserMetrics() async throws -> [String: Any]? {
        let url = URL(string: "\(supabaseUrl)/rest/v1/rpc/get_active_user_metrics")!
        let (data, _) = try await authorizedRequest(url, method: "POST", jsonBody: [:])
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
    
    func updateStudyMetrics(minutesToAdd: Int) async throws -> [String: Any] {
        let url = URL(string: "\(supabaseUrl)/rest/v1/rpc/increment_study_metrics")!
        let body: [String: Any] = ["p_minutes": minutesToAdd]
        
        let (data, response) = try await authorizedRequest(url, method: "POST", jsonBody: body)
        
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? ""
            print("Supabase: increment_study_metrics failed -> \(errorBody)")
            throw NSError(domain: "Supabase", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to update metrics"])
        }
        
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
    
    // --- Study Sessions ---
    
    func fetchStudySessions() async throws -> [StudySession] {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return [] }
        let url = URL(string: "\(supabaseUrl)/rest/v1/study_sessions?user_id=eq.\(userId)&select=*&order=date.desc")!
        let (data, response) = try await authorizedRequest(url)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
             print("Supabase: Study sessions table check failed (maybe not present) status: \(httpResponse.statusCode)")
             return []
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([StudySession].self, from: data)
    }
    
    func upsertStudySession(id: String, date: Date, durationMinutes: Int, type: String) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return }
        let url = URL(string: "\(supabaseUrl)/rest/v1/study_sessions")!
        
        let body: [String: Any] = [
            "id": id,
            "user_id": userId,
            "date": ISO8601DateFormatter().string(from: date),
            "duration_minutes": durationMinutes,
            "type": type
        ]
        
        _ = try await authorizedRequest(url, method: "POST", jsonBody: body, prefer: "resolution=merge-duplicates")
    }
    
    // --- Credits ---
    
    func deductCredits(amount: Int) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return }
        
        let url = URL(string: "\(supabaseUrl)/rest/v1/rpc/deduct_credits")!
        let body: [String: Any] = [
            "p_user_id": userId,
            "p_amount": amount
        ]
        
        _ = try await authorizedRequest(url, method: "POST", jsonBody: body)
    }
    
    // --- News Interaction ---
    
    func getSavedNews() async throws -> [NewsArticle] {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return [] }
        let url = URL(string: "\(supabaseUrl)/rest/v1/saved_news?user_id=eq.\(userId)&select=article_id,news_articles(*)")!
        var request = URLRequest(url: url)
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(authToken ?? "")", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
        return json.compactMap { item in
            let articleRaw = item["news_articles"]
            let articleData: [String: Any]?
            if let obj = articleRaw as? [String: Any] {
                articleData = obj
            } else if let arr = articleRaw as? [[String: Any]], let first = arr.first {
                articleData = first
            } else {
                articleData = nil
            }

            if let articleData = articleData,
               let decodedData = try? JSONSerialization.data(withJSONObject: articleData) {
                return try? JSONDecoder().decode(NewsArticle.self, from: decodedData)
            }
            return nil
        }
    }
    
    func toggleSaveNews(articleId: String, isSaving: Bool) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return }
        var urlString = "\(supabaseUrl)/rest/v1/saved_news"
        if !isSaving {
            urlString += "?user_id=eq.\(userId)&article_id=eq.\(articleId)"
        }
        let url = URL(string: urlString)!
        let body = isSaving ? ["user_id": userId, "article_id": articleId] : nil
        
        let (_, response) = try await authorizedRequest(url, method: isSaving ? "POST" : "DELETE", jsonBody: body)
        if let httpRes = response as? HTTPURLResponse, !(200...299).contains(httpRes.statusCode) {
             // Handle duplicate error (23505) silently if saving
             if isSaving && httpRes.statusCode == 409 { return }
             throw NSError(domain: "Supabase", code: httpRes.statusCode, userInfo: nil)
        }
    }
    
    func updateUpvote(itemId: String, table: String, increment: Int) async throws {
        // Fetch current upvotes first
        let url = URL(string: "\(supabaseUrl)/rest/v1/\(table)?id=eq.\(itemId)&select=upvotes")!
        let (data, _) = try await authorizedRequest(url)
        guard let result = (try JSONSerialization.jsonObject(with: data) as? [[String: Any]])?.first,
              let currentCount = result["upvotes"] as? Int else { return }
        
        let upUrl = URL(string: "\(supabaseUrl)/rest/v1/\(table)?id=eq.\(itemId)")!
        _ = try await authorizedRequest(upUrl, method: "PATCH", jsonBody: ["upvotes": currentCount + increment])
    }

    func deleteModule(id: String) async throws {
        // 1. Soft-delete linked lectures first
        let lectUrl = URL(string: "\(supabaseUrl)/rest/v1/lectures?module_id=eq.\(id)")!
        _ = try? await authorizedRequest(lectUrl, method: "PATCH", jsonBody: ["is_deleted": true])
        
        // 2. Soft-delete linked deadlines (assuming deadlines table also has is_deleted)
        let deadUrl = URL(string: "\(supabaseUrl)/rest/v1/deadlines?module_id=eq.\(id)")!
        _ = try? await authorizedRequest(deadUrl, method: "PATCH", jsonBody: ["is_deleted": true])
        
        // 3. Soft-delete the module itself
        let url = URL(string: "\(supabaseUrl)/rest/v1/user_modules?id=eq.\(id)")!
        let (_, response) = try await authorizedRequest(url, method: "PATCH", jsonBody: ["is_deleted": true])
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw NSError(domain: "SupabaseData", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to soft delete module"])
        }
    }

    // --- Profile & Avatars ---

    func uploadAvatar(data: Data) async throws -> String {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { throw NSError(domain: "Auth", code: 401, userInfo: nil) }
        let url = URL(string: "\(supabaseUrl)/storage/v1/object/profile-pictures/avatars/\(userId).jpg")!
        
        // Using upsert=true via x-upsert header or POST with upsert logic
        // Most Supabase storage implementations use POST to a specific path for upload.
        // We'll use the same authorizedRequest but ensure we handle the path correctly.
        let (_, response) = try await authorizedRequest(url, method: "POST", body: data, contentType: "image/jpeg")
        
        // Handle 409 if already exists? Supabase storage POST usually needs an upsert header
        // For now, if it fails with 409, we'll try a different method or assume success if it's already there
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) && httpResponse.statusCode != 409 {
             throw NSError(domain: "SupabaseStorage", code: httpResponse.statusCode, userInfo: nil)
        }
        
        return "\(supabaseUrl)/storage/v1/object/public/profile-pictures/avatars/\(userId).jpg"
    }

    func updateProfile(updates: [String: Any]) async throws {
        guard let userId = UserDefaults.standard.string(forKey: "supabase_user_id") else { return }
        let url = URL(string: "\(supabaseUrl)/rest/v1/profiles?id=eq.\(userId)")!
        let (_, response) = try await authorizedRequest(url, method: "PATCH", jsonBody: updates)
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw NSError(domain: "SupabaseProfile", code: httpResponse.statusCode, userInfo: nil)
        }
    }
    
    func deleteAccount() async throws {
        let url = URL(string: "\(supabaseUrl)/rest/v1/rpc/delete_user_account")!
        let (data, response) = try await authorizedRequest(url, method: "POST", jsonBody: [:])
        
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "No body"
            print("Supabase Delete Account Error [\(httpResponse.statusCode)]: \(errorBody)")
            throw NSError(domain: "SupabaseAuth", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete account: \(errorBody)"])
        }
    }
}
