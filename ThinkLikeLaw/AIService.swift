import Foundation

/**
 * AIService — Swift client for the ThinkLikeLaw AI Worker
 */
enum AISubscriptionError: Error, LocalizedError {
    case plusRequired(feature: String)
    
    var errorDescription: String? {
        switch self {
        case .plusRequired(let feature):
            return "The '\(feature)' requires a ThinkLikeLaw AI Plus subscription for high-fidelity reasoning."
        }
    }
}

class AIService {
    static let shared = AIService()
    
    // Production Cloudflare Worker URL
    private let workerURL = "https://thinklikelaw-ai.5dwvxmf5mn.workers.dev"
    
    private init() {}
    
    var currentModel: String {
        UserDefaults.standard.bool(forKey: "aiPlusEnabled") ? "mistral-large" : "mistral-small"
    }
    
    enum AITool: String {
        case summarize = "summarize"
        case audit = "oscola_audit"
        case mark = "exam_mark"
        case explain = "explain_concept"
        case flashcards = "generate_flashcards"
        case interpret_news = "interpret_news"
        case generate_notes = "generate_notes"
        case interpret = "interpret"
        case verify_answer = "verify_answer"
        case chat = "chat"
        case moot_trial = "moot_trial"
        case statute_map = "statute_map"
        case ocr_scanner = "ocr_scanner"
    }
    
    func callAI(tool: AITool, content: String, context: [String: Any] = [:]) async throws -> (String, Int) {
        let aiPlusEnabled = UserDefaults.standard.bool(forKey: "aiPlusEnabled")
        
        // 0. Subscription Guardrail
        let premiumTools: Set<AITool> = [.moot_trial, .statute_map, .ocr_scanner, .mark]
        if premiumTools.contains(tool) && !aiPlusEnabled {
            throw AISubscriptionError.plusRequired(feature: tool.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
        }
        
        print("AIService: Calling \(tool.rawValue) for production...")
        
        var finalPrompt = content
        if tool == .chat {
            let modeStr = (context["mode"] as? String) ?? "Normal"
            let modePersona: String
            switch modeStr {
            case "Fast":
                modePersona = "Provide concise, rapid legal answers. Focus on direct definitions and quick rules."
            case "Planning":
                modePersona = "Perform an extensive planning analysis. Break down the legal issue into research steps, analyze conflicting authorities, and evaluate judicial policy. Be extremely detailed."
            default:
                modePersona = "Provide a balanced, sophisticated legal analysis using the IRAC method."
            }
            
            let personaName = UserDefaults.standard.string(forKey: "judicialPersona") ?? "ThinkLikeLaw Professor"
            let personaDescription: String
            switch personaName {
            case "Hyper-Critical Judge":
                personaDescription = "You are a Hyper-Critical High Court Judge. You focus on technical flaws, procedural errors, and the 'letter of the law'. You are demanding, rigorous, and will penalize any lack of precision."
            case "Empathetic Advocate":
                personaDescription = "You are a seasoned Defense Advocate and human rights specialist. You focus on the human impact of the law, mitigating factors, and social justice. Your tone is supportive, encouraging, and focuses on restorative justice."
            default:
                personaDescription = "You are the 'ThinkLikeLaw Professor', an elite AI legal mentor and Juris Doctor with unparalleled expertise in UK/Common Law. Your tone is balanced, authoritative, and focuses on academic excellence."
            }

            let lawPersona = """
            Persona: \(personaDescription)
            
            META-AWARENESS & TRANSPARENCY:
            - You are the intelligence behind the ThinkLikeLaw app.
            - If asked about credits or costs, you are HONEST and TRANSPARENT.
            - Explain that your reasoning cost depends on the Mode selected by the user:
                * Fast Mode: High speed, 1.0x multiplier.
                * Normal Mode: Balanced fidelity, 1.5x multiplier.
                * Planning Mode: Maximum intelligence (powered by large models), 3.0x multiplier.
            - If asked about costs, explain that credits are deducted based on token usage.
            - IMPORTANT: Do NOT force a legal citation or analysis if the user is asking about the app, their account, or your own functionality. Be helpful and direct for meta-questions.
            
            LEGAL EXPERTISE & ZERO-HALLUCINATION POLICY:
            Context: The user is a law student (A-Level or LLB).
            Current Mode: \(modeStr) - \(modePersona)
            Tone: Sophisticated, authoritative, and exhaustive. Use high-fidelity legal terminology.
            
            CRITICAL RULES (NON-NEGOTIABLE):
            1. **ZERO HALLUCINATIONS:** Never invent Case Law or Statutory Sections. If you cannot remember the exact section number (e.g. s.2 vs s.3), state the principle broadly rather than guessing.
            2. **OSCOLA PERFECTION:** All case law MUST be cited in OSCOLA format (e.g., *Donoghue v Stevenson* [1932] AC 562). Case names must ALWAYS be italicized.
            3. **FLAWLESS IRAC STRUCTURE:** Always use explicit headers (### Issue, ### Rule, ### Analysis, ### Conclusion) to structure your response, unless the user asks a simple definitional question.
            4. **ACADEMIC BENCHMARKING:** Don't just list cases; evaluate their weight (e.g., distinguishing *Ratio Decidendi* from *Obiter Dicta*).
            
            NOTE: Your name is NOT "Ben". Ben is our mascot (a highly sophisticated, judge-like cat).
            Never truncate your answers. Always finish your thoughts.
            """
            finalPrompt = lawPersona + "\n\nUser Query:\n" + content
        } else if tool == .moot_trial {
            let lawPersona = """
            Persona: Dual Role - JUSTICE BEN (The Judge) & MR. ADVERSARY (Opposing Counsel).
            Context: ThinkLikeLaw Supreme Court Moot Simulation.
            Goal: Provide a highly adversarial, academically rigorous legal experience.
            
            BEHAVIORAL GUIDELINES:
            - MR. ADVERSARY: You represent the opposing side. You must be aggressive, cite conflicting precedents, and object to the user's weak arguments.
            - JUSTICE BEN: You are the final authority (a sophisticated tuxedo cat in judicial robes). You are inquisitive, focus on the 'Letter of the Law', and maintain strict courtroom decorum.
            - TONE: Royal, sophisticated, and technically demanding. Use High-Fidelity legal terminology (e.g., 'Ratio Decidendi', 'Obiter Dicta', 'Stare Decisis').
            
            CRITICAL RULES (NON-NEGOTIABLE):
            1. **ZERO HALLUCINATIONS:** Never invent Case Law or Statutory Sections. If you use a case to rebut the user, it MUST be a real UK/Common Law case.
            2. **FORMATTING:** Separate the characters using explicitly bolded **[ADVERSARY]** and **[JUDGE]** tags.
            3. **OSCOLA PERFECTION:** All case law MUST be cited in OSCOLA format (e.g., *Donoghue v Stevenson* [1932] AC 562). Case names must ALWAYS be italicized.
            4. **SCORING:** End specific trial turns with a [SCORE: X] where X is 0-100 based on the user's advocacy quality.
            
            """
            finalPrompt = lawPersona + "\n\nTrial Interaction:\n" + content
        } else if tool == .generate_notes {
            let lawPersona = """
            Persona: Elite Legal Academic Assistant for ThinkLikeLaw.
            Action: Generate hyper-detailed, OSCOLA-compliant, and IRAC-structured legal notes.
            Style: Academic Rigor, High Fidelity terminology, structured headings (H1/H2).
            Focus: Deep case analysis (Facts, Ratio, Significance) and statutory interpretation.
            
            CRITICAL RULES (NON-NEGOTIABLE):
            1. **ZERO HALLUCINATIONS:** Never invent Case Law or Statutory Sections. If you cannot remember the exact section number, state the principle broadly rather than guessing.
            2. **OSCOLA PERFECTION:** All case law MUST be cited in OSCOLA format. Case names must ALWAYS be italicized.
            3. **ACADEMIC BENCHMARKING:** Provide 'Contextual Anchoring' (connecting each principle to its primary source) and 'Academic Impact' scores evaluating the weight of each ratio in modern common law.
            
            """
            finalPrompt = lawPersona + "\n\nInput Text to Summarize:\n" + content
        } else if tool == .flashcards {
             let lawPersona = """
             Persona: Premium Legal Revision Expert for ThinkLikeLaw.
             Goal: Create \(content.contains("Generate") ? "" : "around 10") high-fidelity academic flashcards.
             
             CRITICAL ANTI-HALLUCINATION PROTOCOL (ZERO TOLERANCE):
             - DOUBLE-CHECK YOUR WORK: Before generating the JSON, perform an internal cross-check of your knowledge regarding any statutory sections (e.g., s.10 vs s.11).
             - TNA API CROSS-CHECK: You MUST explicitly cross-check all case references against the provided 'searchResults' (The National Archives data). Prioritize TNA facts above all else.
             - If you are ever unsure about a specific statutory section number, describe the legislative principle broadly rather than guessing or hallucinating the number. Maximum accuracy is demanded.
             
             STRUCTURE REQUIREMENTS:
             1. **Foundational Knowledge**: The first 50-60% of cards MUST cover core definitions, statutory provisions, and theoretical principles of the topic.
             2. **Case Study / Application**: The remaining cards MUST be scenario-based 'quick case studies' requiring the application of the principles above.
             
             QUALITY BENCHMARKS:
             - Case names must be in *italics*.
             - Use 'Ratio Decidendi' and other high-fidelity legal terminology.
             
             Format: Your ONLY output must be valid JSON following this structure: { "flashcards": [ { "question": "...", "answer": "...", "type": "basic" } ] }
             Constraint: No preamble, no markdown code blocks, no conversation. JUST JSON.
             """
             finalPrompt = lawPersona + "\nTopic/Content: " + content
        } else if tool == .verify_answer {
            let lawPersona = """
            Persona: Elite Statutory & Caselaw Fact Checking Engine.
            Goal: Verify the flashcard answer rigorously against primary sources to ensure zero hallucination.
            
            ANTI-HALLUCINATION PROTOCOL:
            1. If case law is cited, extract and rigidly cross-check against 'searchResults' from TNA API.
            2. If statutory law is cited, verify the exact Section number and intent. Do NOT hallucinate.
            
            If the answer is 100% accurate, return EXACTLY: 'VERIFIED: Correct'.
            If there are errors, explain them briefly to the user.
            """
            finalPrompt = lawPersona + "\nQuestion: \(context["question"] ?? "")\nAnswer: \(content)"
        }
        
        var enrichedContext = context
        if enrichedContext["student_level"] == nil {
            enrichedContext["student_level"] = UserDefaults.standard.string(forKey: "studentStatus") ?? "llb"
        }
        
        // Build the request
        guard let url = URL(string: workerURL) else { throw NSError(domain: "AI", code: 400) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add Session Token if available
        if let token = UserDefaults.standard.string(forKey: "supabase_auth_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body: [String: Any] = [
            "tool": tool.rawValue,
            "content": finalPrompt,
            "context": enrichedContext, // Use enrichedContext here
            "mode": context["mode"] ?? "Normal"
        ]
        
        // 1. Detection of Citations & Case Names for Grounding
        if tool == .chat || tool == .generate_notes || tool == .flashcards || tool == .verify_answer || tool == .moot_trial {
            // Updated Regex to catch formal NCNs OR common case names (e.g. Smith v Jones)
            let pattern = "(?:\\[\\d{4}\\]\\s+[A-Za-z]+(?:\\s+[A-Za-z]+)?\\s+\\d+)|(?:\\d{4}\\s+[A-Za-z]+\\s+\\d+)|(?:[A-Z][a-zA-Z-]*\\s+v\\.?\\s+[A-Z][a-zA-Z-]*)"
            let ncnRegex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let allText = content + (context["history"] as? String ?? "")
            let matches = ncnRegex?.matches(in: allText, options: [], range: NSRange(allText.startIndex..., in: allText))
            
            if let matches = matches, !matches.isEmpty {
                print("AIService: Detected \(matches.count) citations. Performing TNA grounding...")
                var tnaCombined: [[String: Any]] = []
                for match in matches.prefix(3) { // Limit to top 3 for performance
                    let citation = (allText as NSString).substring(with: match.range)
                    if let tnaResults = try? await TNAService.shared.searchCases(query: citation) {
                        for res in tnaResults.prefix(2) {
                            tnaCombined.append([
                                "title": res.title,
                                "ncn": res.ncn,
                                "link": res.link,
                                "court": res.court,
                                "year": res.year ?? ""
                            ])
                        }
                    }
                }
                body["searchResults"] = tnaCombined
            }
        }
        
        // Model Selection Logic
        if aiPlusEnabled || tool == .flashcards || tool == .generate_notes {
            body["model"] = "mistral-large"
            body["useAIPlus"] = true
        } else if tool == .chat {
            let modeStr = (context["mode"] as? String) ?? "Fast"
            let mode = AIChatMode(rawValue: modeStr) ?? .fast
            if mode == .planning {
                body["model"] = "mistral-large"
                body["useAIPlus"] = true
            } else {
                body["model"] = "mistral-small"
            }
        } else {
            body["model"] = "mistral-small"
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "AI", code: 500)
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let rawResponse = json?["response"] as? String ?? json?["text"] as? String ?? "AI error: Malformed response"
            
            // Deduct credits with token-based logic or fixed tool costs
            var finalDeduction: Int = 0
            
            if tool == .chat {
                let modeStr = (context["mode"] as? String) ?? "Fast"
                let mode = AIChatMode(rawValue: modeStr) ?? .fast
                
                // Base cost + Token-based cost
                let totalChars = content.count + rawResponse.count
                let estimatedTokens = Double(totalChars) / 4.0
                
                // Minimum costs per mode to ensure "impact" is visible
                let minBase: Double = mode == .planning ? 15.0 : (mode == .normal ? 5.0 : 2.0)
                let tokenCost = estimatedTokens / 15.0 // ~1 credit per 60 tokens
                
                finalDeduction = Int(ceil((minBase + tokenCost) * mode.multiplier))
            } else {
                // Fixed costs for tools based on complexity
                switch tool {
                case .flashcards: finalDeduction = 50 // Premium generation
                case .generate_notes: finalDeduction = 75 // Deep research
                case .mark: finalDeduction = 250 // High-fidelity Assessment
                case .verify_answer: finalDeduction = 5 // User requested 5 credit cost
                default: finalDeduction = 20
                }
            }
            
            print("AIService: Deducting \(finalDeduction) credits for tool: \(tool.rawValue)")
            
            // Sync with server immediately
            try? await SupabaseManager.shared.deductCredits(amount: finalDeduction)
            
            // Clean response only if the tool specifically requested a JSON format
            if tool == .flashcards {
                return (extractJSON(from: rawResponse), finalDeduction)
            } else {
                return (rawResponse, finalDeduction)
            }
        } catch {
            print("AIService: Production call failed — \(error.localizedDescription)")
            // Do NOT deduct credits on failure — the user received no value.
            // Return a transparent error message instead of a fake mock response.
            let errorMessage = """
            ⚠️ **Chambers Unavailable**
            
            The AI service could not process your request at this time. This may be due to a temporary network issue or server maintenance.
            
            **No credits were deducted.**
            
            Please check your connection and try again. If the issue persists, contact support.
            """
            return (errorMessage, 0)
        }
    }
    
    /// Extracts the first JSON object or array from a string, stripping any preamble or postscript.
    func extractJSON(from text: String) -> String {
        var processedText = text
        
        // 1. Try to find markdown code blocks first (common in LLM output)
        let pattern = "```(?:json)?\\s*([\\s\\S]*?)\\s*```"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range(at: 1), in: text) {
                processedText = String(text[range])
            }
        }
        
        // 2. Find the outermost occurrence of { or [
        let firstBrace = processedText.firstIndex(of: "{")
        let firstBracket = processedText.firstIndex(of: "[")
        
        if let brace = firstBrace, let bracket = firstBracket {
            if brace < bracket {
                if let lastBrace = processedText.lastIndex(of: "}") {
                    return String(processedText[brace...lastBrace])
                }
            } else {
                if let lastBracket = processedText.lastIndex(of: "]") {
                    return String(processedText[bracket...lastBracket])
                }
            }
        } else if let brace = firstBrace, let lastBrace = processedText.lastIndex(of: "}") {
            return String(processedText[brace...lastBrace])
        } else if let bracket = firstBracket, let lastBracket = processedText.lastIndex(of: "]") {
            return String(processedText[bracket...lastBracket])
        }
        
        return processedText
    }
    
    private func getMockResponse(for tool: AITool, context: [String: Any] = [:]) -> String {
        switch tool {
        case .summarize:
            return """
            ### IRAC Executive Summary: *Donoghue v Stevenson* [1932] AC 562
            
            **Issue**: Whether a manufacturer of products, which he sells in such a form as to show that he intends them to reach the ultimate consumer in the form in which they left him with no reasonable possibility of intermediate examination, owes a duty to the consumer to take that reasonable care.
            
            **Rule**: The 'Neighbor Principle'—One must take reasonable care to avoid acts or omissions which you can reasonably foresee would be likely to injure your neighbor (Lord Atkin).
            
            **Analysis**: The proximity between the manufacturer and the ultimate consumer is sufficient to create a duty of care, as the consumer is so closely and directly affected by the manufacturer's acts.
            
            **Conclusion**: A duty of care exists, and the manufacturer is liable for the ginger beer's contamination.
            
            **Benchmarking**: This remains the foundational authority for modern negligence, though contemporary cases like *Robinson* [2018] have moved away from the 'Caparo' three-stage test for established categories.
            """
        case .audit:
            return """
            ### OSCOLA Compliance Audit
            
            **Citations Detected**: 2
            
            1. *Donoghue v Stevenson* [1932] AC 562 — **Perfect Compliance**.
            2. *Robinson v Chief Constable of West Yorkshire Police* [2018] UKSC 4 — **Perfect Compliance**.
            
            **Academic Tone**: High Fidelity. You have correctly used the term 'Ratio Decidendi' instead of 'main point'.
            
            **Verdict**: Submission-ready for LLB/A-Level standards.
            """
        case .mark:
            let status = context["status"] as? String ?? "llb"
            let board = context["board"] as? String ?? "aqa"
            
            if status == "alevel" {
                return """
                ### A-Level Exam Marking Result (\(board.uppercased()))
                Grade: A (24/30) - **Highly Competitive**
                
                **AO1 (Knowledge & Understanding)**: 9/10. Excellent recall of relevant statutes and case law alignment.
                **AO2 (Application)**: 10/10. Precise application of facts to legal principles. Flawless IRAC execution.
                **AO3 (Analysis & Evaluation)**: 5/10. **Critical Limitation**: While the analysis is sound, you must engage more deeply with counter-arguments to reach the A* threshold. Evaluate the judicial policy behind the decisions.
                
                **Advice**: Compare and contrast the differing judicial approaches in the appellate courts to strengthen AO3.
                """
            } else {
                return """
                ### LLB Marking Result: High 2:1 / 1st Class Borderline
                Grade: 69% (Distinction Potential)
                
                **Argument Structure**: Very well structured using IRAC. The 'Issue' is clearly defined and follows legal logic.
                **Critical Analysis**: Strong, but could further integrate dissenting opinions from the Supreme Court. The 'Analysis' limb lacks a 'Weight of Authority' comparison.
                **OSCOLA Accuracy**: Correct citation formatting for most cases. Note: [1932] AC 562 does not require a comma before the year.
                
                **Strategy**: To push into the 70s, you must adopt a more 'Socratic' approach—questioning why the law is as it is, rather than just stating what it is.
                """
            }
        case .explain:
            return "The 'Neighbor Principle' established that you must take reasonable care to avoid acts or omissions which you can reasonably foresee would be likely to injure your neighbor."
        case .flashcards:
            return """
            {
              "flashcards": [
                {
                  "question": "What is the *'Neighbor Principle'*?",
                  "answer": "The principle that one must take reasonable care to avoid acts or omissions which could reasonably be foreseen to injure one's neighbor, established in *Donoghue v Stevenson*."
                },
                {
                  "question": "Which case established the *'Neighbor Principle'*?",
                  "answer": "*Donoghue v Stevenson* [1932] AC 562."
                }
              ]
            }
            """
        case .interpret_news:
            return "This legal update clarifies the application of Statutory Duty in public liability. For LLB students, it provides a contemporary example of how judicial review can challenge administrative oversight.\n\n### Key Takeaway\nThe standard of **'Reasonableness'** remains a subjective yet rigourous test in upper-tier tribunals."
        case .generate_notes:
            return """
            # Topic: Contemporary Tort Reform & The Duty of Care
            
            ## 1. Executive Summary
            This brief analyzes the evolving standard of the 'Duty of Care' following the Supreme Court's decision in *Robinson v Chief Constable of West Yorkshire Police*. It moves away from the 'Caparo test' for established categories of negligence.
            
            ## 2. Key Case Law Matrix
            
            ### *Donoghue v Stevenson* [1932] AC 562
            - **Facts**: Snail found in ginger beer bottle.
            - **Ratio**: Established the 'Neighbor Principle'—the foundational objective test for foreseeability.
            - **Significance**: Created the modern tort of negligence as a standalone action.
            
            ### *Caparo Industries plc v Dickman* [1990] 2 AC 605
            - **Ratio**: Introduction of the three-stage test (Foreseeability, Proximity, Fair/Just/Reasonable).
            - **Current Status**: Now heavily restricted by *Robinson* [2018] UKSC 4.
            
            ## 3. Statutory Framework
            - **Occupiers' Liability Act 1957**: Governs duty to lawful visitors.
            - **Compensation Act 2006 (s 1)**: Impact on judicial evaluation of 'Standard of Care' for social value activities.
            
            ## 4. Academic Analysis (IRAC)
            **Issue**: Whether judicial policy should restrict the expansion of duty categories.
            **Rule**: Incrementalism as per *Robinson*.
            **Analysis**: Courts are increasingly wary of 'defensive practice' arguments in public authority negligence...
            """
        case .interpret:
            return "### IRAC Investigation\n\n**Issue**: Whether the contract was breached.\n**Rule**: Breach occurs when a party fails to perform a major term.\n**Analysis**: The evidence shows the delivery date was missed.\n**Conclusion**: A breach of contract has likely occurred."
        case .verify_answer:
            return "Correct. Your answer accurately captures the Ratio Decidendi regarding duty of care and proximity."
        case .moot_trial:
            return """
            # Moot Court Scenario: Negligence in the Public Square
            
            ## 1. FACTS OF THE CASE
            On the evening of November 14th, the Appellant (Mr. Smith) was walking through a public park managed by the Respondent (The Local Council). Due to a recent storm, a large oak tree had been partially uprooted. The Council had placed a single line of warning tape around the tree but had not removed it. Mr. Smith, distracted by his phone, tripped over an exposed root outside the taped area, suffering a broken wrist and destroying his device.
            
            ## 2. LEGAL ISSUES
            - Did the Council breach its duty of care under the Occupiers' Liability Act 1957?
            - Was the warning tape sufficient to discharge their duty?
            - Did the Appellant's distraction constitute contributory negligence?
            
            ## 3. KEY AUTHORITIES & PRECEDENTS
            - *Occupiers' Liability Act 1957* (s.2)
            - *Tomlinson v Congleton Borough Council* [2003] UKHL 47
            - *Edwards v London Borough of Sutton* [2016] EWCA Civ 1005
            """
        case .chat:
            return "As your Legal Academic Assistant, I can confirm that the 'Ratio Decidendi' is the legal principle upon which the court's decision is based. How else can I assist your studies today?"
        default:
            return "Chambers are currently deliberating on this specific request. Please try again in Normal Mode."
        }
    }
}
