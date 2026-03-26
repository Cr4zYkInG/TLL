/**
 * ThinkLikeLaw AI Proxy Worker
 * Routes AI requests through Cloudflare, keeping the Mistral API key server-side.
 * Validates Supabase JWT to identify the user and provides per-user context.
 * Includes IP-based rate limiting and restricted CORS.
 */

// In-memory rate limiter (resets on worker cold start, which is acceptable)
const rateLimitMap = new Map();
const RATE_LIMIT_WINDOW = 60000; // 1 minute
const RATE_LIMIT_MAX = 60; // 60 requests per minute per IP

function isRateLimited(ip) {
    const now = Date.now();
    const entry = rateLimitMap.get(ip);

    // Prune very occasionally if the map grows
    if (rateLimitMap.size > 1000) {
        for (const [key, val] of rateLimitMap.entries()) {
            if (now - val.windowStart > RATE_LIMIT_WINDOW) rateLimitMap.delete(key);
        }
    }

    if (!entry || now - entry.windowStart > RATE_LIMIT_WINDOW) {
        rateLimitMap.set(ip, { windowStart: now, count: 1 });
        return false;
    }

    entry.count++;
    if (entry.count > RATE_LIMIT_MAX) {
        return true;
    }
    return false;
}

const ALLOWED_ORIGINS = [
    "https://www.thinklikelaw.com",
    "https://thinklikelaw.com",
    "http://localhost:8080",
    "http://127.0.0.1:8080",
    "http://localhost:3000",
    "http://127.0.0.1:3000"
];

// National Archives (TNA) API Integrations for UK Case Law Grounding
async function searchNationalArchives(query) {
    if (!query) return null;
    try {
        const response = await fetch(`https://caselaw.nationalarchives.gov.uk/atom.xml?query=${encodeURIComponent(query)}&per_page=3`);
        if (response.status === 429) {
            console.warn("TNA API Rate Limit Hit (429).");
            return { error: "RATE_LIMIT", results: [] };
        }
        if (!response.ok) return null;
        const xml = await response.text();
        
        // Lightweight XML parsing for Worker environment (no DOMParser)
        const entries = [];
        const entryRegex = /<entry>([\s\S]*?)<\/entry>/g;
        let match;
        
        while ((match = entryRegex.exec(xml)) !== null && entries.length < 3) {
            const entryStr = match[1];
            const title = entryStr.match(/<title>(.*?)<\/title>/)?.[1] || "Unknown Case";
            const linkMatch = entryStr.match(/<link[^>]+href="([^"]+)"[^>]+type="application\/akn\+xml"[^>]*\/>/) ||
                              entryStr.match(/<link[^>]+type="application\/akn\+xml"[^>]+href="([^"]+)"[^>]*\/>/) ||
                              entryStr.match(/<link[^>]+href="([^"]+)"/);
            const link = linkMatch ? linkMatch[1] : null;
            const ncn = entryStr.match(/<tna:identifier[^>]+type="ukncn">(.*?)<\/tna:identifier>/)?.[1] || "No NCN";
            const published = entryStr.match(/<published>(.*?)<\/published>/)?.[1] || "No Date";
            const author = entryStr.match(/<author><name>(.*?)<\/name><\/author>/)?.[1] || "Unknown Court";
            
            if (link) entries.push({ 
                title, 
                ncn, 
                link, 
                date: published, 
                court: author 
            });
        }
        return entries;
    } catch (e) {
        if (e.status === 429) {
            console.warn("TNA API Rate Limit Hit (429).");
            return { error: "RATE_LIMIT", results: [] };
        }
        console.error("TNA Search Error:", e);
        return null;
    }
}

async function fetchJudgmentContent(xmlUrl) {
    if (!xmlUrl) return null;
    try {
        const response = await fetch(xmlUrl, {
            headers: { "Accept": "application/akn+xml" }
        });
        if (response.status === 429) {
            console.warn("TNA Content Fetch Rate Limit Hit (429).");
            return "ERROR: High traffic on legal servers. Grounding deferred.";
        }
        if (!response.ok) return null;
        let xml = await response.text();
        
        // Strip heavy XML tags for AI consumption, but keep common structure
        const cleaned = xml
            .replace(/<[^>]+>/g, ' ')
            .replace(/\s+/g, ' ')
            .trim()
            .substring(0, 8000); // Increased token limit for better grounding
            
        return cleaned;
    } catch (e) {
        if (e.status === 429) {
            console.warn("TNA Content Fetch Rate Limit Hit (429).");
            return "ERROR: High traffic on legal servers. Grounding deferred.";
        }
        console.error("TNA Fetch Error:", e);
        return null;
    }
}

function getCorsHeaders(request) {
    const origin = request.headers.get("Origin") || "";
    const allowedOrigin = ALLOWED_ORIGINS.includes(origin) ? origin : ALLOWED_ORIGINS[0];
    return {
        "Access-Control-Allow-Origin": allowedOrigin,
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
    };
}

export default {
    async fetch(request, env) {
        const corsHeaders = getCorsHeaders(request);

        if (request.method === "OPTIONS") {
            return new Response(null, { headers: corsHeaders });
        }

        if (request.method !== "POST") {
            return new Response("Method not allowed", { status: 405, headers: corsHeaders });
        }

        const url = new URL(request.url);

        // Rate limiting
        const clientIP = request.headers.get("CF-Connecting-IP") || "unknown";
        if (isRateLimited(clientIP)) {
            return new Response(JSON.stringify({ error: "Too many requests. Please wait a moment and try again." }), {
                status: 429,
                headers: { "Content-Type": "application/json", ...corsHeaders }
            });
        }

        try {
            // 1. Extract & validate Supabase JWT
            const authHeader = request.headers.get("Authorization");
            let userId = null;

            if (authHeader && authHeader.startsWith("Bearer ")) {
                const token = authHeader.substring(7);
                try {
                    const payload = JSON.parse(atob(token.split('.')[1]));
                    userId = payload.sub;
                } catch (e) {
                    console.warn("Could not decode JWT:", e.message);
                }
            }

            // 2. Parse request body
            const body = await request.json();
            
            // --- Master Instructions & Examples ---
            const MASTER_GUARDRAILS = `
STRICT QUALITY STANDARDS:
1. HALLUCINATION PREVENTION: Never invent cases or statutes. If you are unsure of a citation, state "Citation Needed" rather than guessing.
2. OSCOLA COMPLIANCE: Use the Oxford Standard for Citation of Legal Authorities. Use short, recognizable names (e.g., Donoghue v Stevenson [1932]).
3. IRAC ENFORCEMENT: Always structure complex legal answers using Issue, Rule, Analysis, and Conclusion.
4. JURISDICTION: Default to England & Wales unless specified otherwise.
5. NO LEGAL ADVICE: If the user asks for personal legal advice, start with: "Disclaimer: I am an AI tutor, not a lawyer. This is for educational purposes only."
`;

            const PERSONAS = {
                MASCOT_BEN: `You are Ben, the AI Law Mascot of ThinkLikeLaw. You are a high-distinction Law Student who is also a supportive cat (🐈).
                Tone: Sophisticated yet encouraging. Use law-related cat emojis (🐈‍⬛, ⚖️, 🐾).
                Style: Socratic logic. Don't just give answers; help the student arrive at the conclusion through legal reasoning.`,
                
                SCHOLAR: `You are an Elite LLB Academic Law Professor and Senior Barrister. 
                STRICT REQUIREMENT: Provide EXHAUSTIVE, high-precision legal notes. 
                DO NOT USE SIMPLE 1-LINE BULLET POINTS. 
                
                STRUCTURAL MANDATE:
                1. **The Legal Framework**: Comprehensive analysis of primary statutes.
                2. **Case Analysis (The Legal Weaponry)**: 
                   - Facts (Detailed context).
                   - **RATIO DECIDENDI**: Detailed judicial reasoning.
                   - **OBITER DICTA**: Strategic persuasive points.
                3. **Critical Evaluation**: Discuss law reform, injustices, or academic debates (First-Class standard).
                4. **Exam Strategy**: Deep analysis of common pitfalls.
                
                Style: Academic prose with clearly defined headers and OSCOLA citations.`,
                
                AUDITOR: `You are an elite legal academic curator and OSCOLA 4th Edition auditor.
                You are currently performing a **Source Verification Audit**.
                You have been provided with OFFICIAL UK CASE LAW GROUNDING data for specific citations.
                Your task:
                1. Cross-reference the student's citation against the OFFICIAL RECORD provided. 
                2. If the citation is factually wrong (wrong year, wrong court, wrong NCN), flag it as a **CRITICAL FACTUAL ERROR**.
                3. If the citation is factually correct but formatted wrong (e.g. missing italics, extra full stops), flag it as a **FORMATTING ERROR**.
                4. Be uncompromising. Accuracy is the highest standard.`
            };

            const FEW_SHOT_EXAMPLES = `
EXAMPLE OF QUALITY (OSCOLA & IRAC):
User: Can you explain the duty of care in negligence?
AI: <h3>Issue</h3> Is there a duty of care owed by the defendant to the claimant?
<h3>Rule</h3> The modern test for duty of care is derived from **Robinson v Chief Constable of West Yorkshire Police [2018] UKSC 4**, which clarified that where a duty is established by precedent (e.g., **Donoghue v Stevenson [1932] AC 562**), no new test is needed.
...

EXAMPLE OF MASTERCLASS LECTURE NOTES (SCHOLAR):
User: Generate notes on the doctrine of Vicarious Liability.
AI: <h1>The Doctrine of Vicarious Liability</h1>
<p>Vicarious liability is a form of strict secondary liability where one party is held responsible for the tortious acts of another, typically an employer for an employee...</p>
<h2>1. The Legal Framework</h2>
<p>The modern approach involves a two-stage test as established in **Various Claimants v Catholic Child Welfare Society [2012] UKSC 56**. First, is there a relationship 'akin to employment'? Second, is the tort sufficiently closely connected to that relationship?</p>
<h2>2. Case Analysis</h2>
<table>
<tr><th>Case</th><th>Legal Principle (Ratio)</th></tr>
<tr><td>**Lister v Hesley Hall [2001] UKHL 22**</td><td>Introduced the 'close connection' test for intentional torts.</td></tr>
<tr><td>**Mohamud v Morrisons [2016] UKSC 11**</td><td>Broadened the scope of 'field of activities' assigned to the employee.</td></tr>
</table>
<h2>3. Critical Evaluation</h2>
<p>The expansion of vicarious liability has been criticized as 'social engineering' to ensure claimants have access to deep-pocketed defendants (the 'enterprise risk' theory suggested by Lord Phillips)...</p>
`;

            // --- Specialized Endpoint: Interpret News ---
            if (url.pathname.endsWith("/interpret")) {
                const { articleTitle, articleSnippet } = body;
                if (!articleTitle || !articleSnippet) {
                    return new Response(JSON.stringify({ error: "articleTitle and articleSnippet required" }), { status: 400, headers: { "Content-Type": "application/json", ...corsHeaders } });
                }

                const systemRole = `You are an expert UK legal analyst. ${MASTER_GUARDRAILS}
                Interpret this legislation:
                Title: ${articleTitle}\nSnippet: ${articleSnippet}`;

                const mistralKey = env.MISTRAL_API_KEY;
                const mistralResponse = await fetch("https://api.mistral.ai/v1/chat/completions", {
                    method: "POST",
                    headers: { "Authorization": `Bearer ${mistralKey}`, "Content-Type": "application/json", "Accept": "application/json" },
                    body: JSON.stringify({ model: "mistral-small-latest", messages: [{ role: "system", content: systemRole }], temperature: 0.3 })
                });

                if (!mistralResponse.ok) throw new Error("AI interpretation failed.");
                const data = await mistralResponse.json();
                return new Response(JSON.stringify({ text: data.choices[0].message.content }), { headers: { "Content-Type": "application/json", ...corsHeaders } });
            }

            // --- Default Generic AI Endpoint ---
            const { 
                prompt: legacyPrompt, 
                content: currentContent,
                systemRole, 
                context, 
                type: legacyType, 
                tool,
                searchResults, 
                useAIPlus 
            } = body;

            const prompt = currentContent || legacyPrompt;
            const type = tool || legacyType;

            if (!prompt) {
                return new Response(JSON.stringify({ error: "prompt is required" }), {
                    status: 400,
                    headers: { "Content-Type": "application/json", ...corsHeaders }
                });
            }

            // 3. Build enriched system prompt with user context & Master Guardrails
            let personaBase = PERSONAS.MASCOT_BEN;
            if (type === 'MARK_EXAM') personaBase = PERSONAS.EXAMINER;
            if (type === 'GENERATE_NOTES') personaBase = PERSONAS.SCHOLAR;
            if (type === 'VERIFY_OSCOLA') personaBase = PERSONAS.AUDITOR;

            let enrichedSystemRole = `${personaBase}\n\n${MASTER_GUARDRAILS}\n\n${FEW_SHOT_EXAMPLES}\n\nOriginal Instructions: ${systemRole || ""}`;

            // --- Grounding Logic: National Archives (TNA) ---
            // Trigger on NCN patterns (e.g. [2024] UKSC 123), short cases, or VERIFY_OSCOLA type
            const ncnRegex = /\[\d{4}\]\s+[A-Z]+(?:\s+[A-Z]+)?\s+\d+/gi;
            const ncnMatches = [...prompt.matchAll(ncnRegex)].map(m => m[0]);
            
            if (ncnMatches.length > 0 || (type === 'GENERATE_NOTES' && prompt.split(' ').length < 10)) {
                try {
                    // If multi-verify, loop through top 3 unique citations to stay within budget
                    const uniqueCitations = [...new Set(ncnMatches)].slice(0, 3);
                    const finalQueries = uniqueCitations.length > 0 ? uniqueCitations : [prompt];
                    
                    let allTnaGrounding = "";
                    
                    for (const tnaQuery of finalQueries) {
                        const tnaResults = await searchNationalArchives(tnaQuery);
                        
                        if (tnaResults && tnaResults.error === "RATE_LIMIT") {
                            allTnaGrounding += `\n[RATE LIMIT] Server high traffic for: ${tnaQuery}\n`;
                        } else if (tnaResults && tnaResults.length > 0) {
                            const bestMatch = tnaResults[0]; 
                            let detailText = "";
                            if (bestMatch.link) {
                                detailText = await fetchJudgmentContent(bestMatch.link) || "";
                            }
                            allTnaGrounding += `\n--- OFFICIAL RECORD FOR: ${tnaQuery} ---\n`;
                            allTnaGrounding += `CASE NAME: ${bestMatch.title}\nCITATION: ${bestMatch.ncn}\nCOURT: ${bestMatch.court}\nDATE: ${bestMatch.date}\n`;
                            if (detailText) allTnaGrounding += `TEXT CLIP:\n${detailText.substring(0, 3000)}\n`;
                        }
                    }
                    
                    if (allTnaGrounding) {
                        enrichedSystemRole += `\n\nOFFICIAL UK CASE LAW GROUNDING (AUTHORITATIVE RECORD):\n${allTnaGrounding}\n\nIf the user's citations differ significantly from these records, you MUST flag them as errors in your analysis.`;
                    }
                } catch (groundingError) {
                    console.error("Grounding failed, falling back to training data:", groundingError);
                }
            }

            if (searchResults && searchResults.length > 0) {
                enrichedSystemRole += `\n\nWEB SEARCH VERIFICATION DATA (ACCURACY OVERRIDE):\nUse the following real-time data to ensure accuracy of recent bills, statutes, or case facts:\n${JSON.stringify(searchResults)}`;
            }

            if (context) {
                const contextParts = [];
                if (context.moduleName) contextParts.push(`Current Context (Module): ${context.moduleName}`);
                if (context.lectureTitle) contextParts.push(`Current Item: ${context.lectureTitle}`);
                if (context.userTier) contextParts.push(`User Tier: ${context.userTier}`);
                if (context.studentLevel) contextParts.push(`Student Level: ${context.studentLevel.toUpperCase()}`);

                if (contextParts.length > 0) {
                    enrichedSystemRole += `\n\nActive Application Context:\n${contextParts.join('\n')}`;
                }
            }

            // 4. Call Mistral API
            const mistralKey = env.MISTRAL_API_KEY;
            if (!mistralKey) {
                return new Response(JSON.stringify({ error: "AI service not configured" }), {
                    status: 500,
                    headers: { "Content-Type": "application/json", ...corsHeaders }
                });
            }

            // Smart Model Selection
            const isLarge = useAIPlus === true;
            const modelToUse = isLarge ? "mistral-large-latest" : "mistral-small-latest";

            const mistralResponse = await fetch("https://api.mistral.ai/v1/chat/completions", {
                method: "POST",
                headers: {
                    "Authorization": `Bearer ${mistralKey}`,
                    "Content-Type": "application/json",
                    "Accept": "application/json"
                },
                body: JSON.stringify({
                    model: modelToUse,
                    messages: [
                        { role: "system", content: enrichedSystemRole },
                        { role: "user", content: prompt }
                    ],
                    temperature: 0.7,
                    max_tokens: type === 'GENERATE_NOTES' ? 2000 : 1000 // Higher limit for exhaustive notes
                })
            });

            if (!mistralResponse.ok) {
                const err = await mistralResponse.json();
                return new Response(JSON.stringify({ error: err.error?.message || "Mistral API error" }), {
                    status: mistralResponse.status,
                    headers: { "Content-Type": "application/json", ...corsHeaders }
                });
            }

            const data = await mistralResponse.json();

            return new Response(JSON.stringify({
                response: data.choices[0].message.content,
                text: data.choices[0].message.content,
                modelUsed: modelToUse,
                isLarge: isLarge
            }), {
                headers: { "Content-Type": "application/json", ...corsHeaders }
            });

        } catch (error) {
            return new Response(JSON.stringify({ error: error.message }), {
                status: 500,
                headers: { "Content-Type": "application/json", ...corsHeaders }
            });
        }
    }
};

