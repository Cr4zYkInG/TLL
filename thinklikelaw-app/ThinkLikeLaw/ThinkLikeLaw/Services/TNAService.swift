import Foundation

class TNAService {
    static let shared = TNAService()
    
    private init() {}
    
    /**
     * Search the National Archives for cases matching a query (Atom feed)
     */
    func searchCases(query: String) async throws -> [TNACase] {
        guard !query.isEmpty else { return [] }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://caselaw.nationalarchives.gov.uk/atom.xml?query=\(encodedQuery)&per_page=3"
        
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "TNAService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid TNA URL"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "TNAService", code: 500, userInfo: [NSLocalizedDescriptionKey: "No response from TNA"])
        }
        
        if httpResponse.statusCode == 429 {
            print("TNAService: Rate limit hit")
            return []
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "TNAService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "TNA Search Failed: \(httpResponse.statusCode)"])
        }
        
        guard let xmlString = String(data: data, encoding: .utf8) else {
            return []
        }
        
        return parseAtomFeed(xmlString)
    }
    
    /**
     * Fetch the full judgment text from a TNA XML link
     */
    func fetchJudgmentContent(xmlUrl: String) async -> String? {
        guard let url = URL(string: xmlUrl) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.addValue("application/akn+xml", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 429 {
                return "[TNA Rate Limit] Grounding deferred."
            }
            
            guard let xml = String(data: data, encoding: .utf8) else { return nil }
            
            // Basic XML cleaning (similar to website worker)
            let cleaned = xml
                .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return String(cleaned.prefix(8000))
        } catch {
            print("TNAService: Content fetch error: \(error)")
            return nil
        }
    }
    
    private func parseAtomFeed(_ xml: String) -> [TNACase] {
        var cases: [TNACase] = []
        
        // Use regex for lightweight parsing in Atom feed
        let entryPattern = "<entry>([\\s\\S]*?)</entry>"
        guard let entryRegex = try? NSRegularExpression(pattern: entryPattern, options: []) else { return [] }
        
        let nsString = xml as NSString
        let matches = entryRegex.matches(in: xml, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches.prefix(3) {
            let entry = nsString.substring(with: match.range(at: 1))
            
            let title = extract(from: entry, pattern: "<title>(.*?)</title>") ?? "Unknown Case"
            let ncn = extract(from: entry, pattern: "<tna:identifier[^>]+type=\"ukncn\">(.*?)</tna:identifier>") ?? "No NCN"
            let published = extract(from: entry, pattern: "<published>(.*?)</published>") ?? "No Date"
            let court = extract(from: entry, pattern: "<author><name>(.*?)</name></author>") ?? "Unknown Court"
            
            // Try different link versions
            let link = extract(from: entry, pattern: "<link[^>]+href=\"([^\"]+)\"") ?? ""
            
            if !link.isEmpty {
                cases.append(TNACase(title: title, ncn: ncn, link: link, date: published, court: court))
            }
        }
        
        return cases
    }
    
    /**
     * Get a comprehensive case brief for a specific citation
     */
    func getCaseBrief(citation: String) async throws -> (tnacase: TNACase, content: String)? {
        let results = try await searchCases(query: citation)
        guard let first = results.first else { return nil }
        
        // Fetch XML content and clean it
        let xmlUrl = first.link + "/data.xml"
        let content = await fetchJudgmentContent(xmlUrl: xmlUrl) ?? ""
        
        return (first, content)
    }
    
    private func extract(from string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = string as NSString
        if let match = regex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: nsString.length)) {
            return nsString.substring(with: match.range(at: 1))
        }
        return nil
    }
}
