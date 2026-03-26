function getIndustryTag(text) {
    const t = text.toLowerCase();
    if (t.match(/\b(construction|infrastructure|planning|housing|development|building)\b/)) return "Construction & Infrastructure";
    if (t.match(/\b(finance|tax|economy|budget|insurance|pension|bank|investment)\b/)) return "Business & Finance";
    if (t.match(/\b(health|medical|nhs|doctor|hospital|care|medicine)\b/)) return "Healthcare";
    if (t.match(/\b(education|school|university|student|teacher|curriculum)\b/)) return "Education";
    if (t.match(/\b(environment|climate|energy|pollution|green|nature)\b/)) return "Environment";
    if (t.match(/\b(crime|police|justice|prison|court|offence)\b/)) return "Law & Justice";
    if (t.match(/\b(tobacco|vape|food|lifestyle|sport|culture|arts)\b/)) return "Lifestyle & Culture";
    if (t.match(/\b(tech|digital|data|cyber|ai|internet|telecom|broadband)\b/)) return "Technology";
    if (t.match(/\b(transport|rail|train|road|vehicle|air|flight)\b/)) return "Transport";
    return "General";
}

export default {
    async scheduled(event, env, ctx) {
        ctx.waitUntil(this.fetchAndStoreNews(env));
    },

    // Optional: Allow manual trigger via HTTP for testing
    async fetch(request, env, ctx) {
        const url = new URL(request.url);
        if (url.pathname === '/trigger-news') {
            await this.fetchAndStoreNews(env);
            return new Response("News aggregated successfully.", { status: 200 });
        }
        return new Response("News Worker Active. Runs on cron.", { status: 200 });
    },

    async fetchAndStoreNews(env) {
        let allArticles = [];

        // 1. Fetch Legal News (Legislation.gov.uk)
        try {
            // The JSON endpoint is sometimes unreliable or gives HTML, so we parse the Atom XML feed.
            const legUrl = `https://www.legislation.gov.uk/new/data.feed`;
            const req = await fetch(legUrl, {
                headers: {
                    'Accept': 'application/atom+xml,application/xml',
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ThinkLikeLawWorker/1.0'
                }
            });
            const xml = await req.text();

            const entryRegex = /<entry>([\s\S]*?)<\/entry>/g;
            let match;
            let count = 0;
            const recentLegislation = [];

            while ((match = entryRegex.exec(xml)) !== null && count < 15) {
                const content = match[1];
                const titleMatch = /<title>([\s\S]*?)<\/title>/.exec(content);
                const idMatch = /<id>([\s\S]*?)<\/id>/.exec(content);
                const summaryMatch = /<summary>([\s\S]*?)<\/summary>/.exec(content);
                const updatedMatch = /<updated>([\s\S]*?)<\/updated>/.exec(content);

                const title = titleMatch ? titleMatch[1].replace(/<!\[CDATA\[|\]\]>/g, '').trim() : "New Legislation";
                const url = idMatch ? idMatch[1].trim() : "";

                let snippet = `New legislation enacted: ${title}`;
                if (summaryMatch && summaryMatch[1].trim()) {
                    snippet = summaryMatch[1].replace(/<!\[CDATA\[|\]\]>/g, '').replace(/<[^>]+>/g, '').trim();
                }

                if (url && title) {
                    recentLegislation.push({
                        title: title,
                        url: url,
                        source: 'Legislation.gov.uk',
                        category: 'Legal',
                        industry_tag: getIndustryTag(title + " " + snippet),
                        snippet: snippet,
                        image_url: null,
                        published_at: updatedMatch ? updatedMatch[1].trim() : new Date().toISOString()
                    });
                    count++;
                }
            }
            allArticles = allArticles.concat(recentLegislation);
        } catch (e) {
            console.error("Failed fetching Legal News:", e);
        }

        // 2. Fetch Parliamentary News (UK Parliament API - Committes or Bills)
        try {
            // Using the Parliament Bills API as an example of parliamentary activity
            const parlUrl = `https://bills-api.parliament.uk/api/v1/Bills?SortOrder=DateUpdatedDescending&Take=15`;
            const req = await fetch(parlUrl, { headers: { 'accept': 'application/json' } });
            const data = await req.json();

            if (data && data.items) {
                const parlPromises = data.items.map(async (item) => {
                    let snippet = item.summary || `Bill update: ${item.currentStage?.description || 'Recent activity'}`;
                    let title = item.title || item.shortTitle || "Parliamentary Bill";

                    // Try to fetch additional news article for this bill to get richer content
                    try {
                        const newsUrl = `https://bills-api.parliament.uk/api/v1/Bills/${item.billId}/NewsArticles`;
                        const newsReq = await fetch(newsUrl, { headers: { 'accept': 'application/json' } });
                        if (newsReq.ok) {
                            const newsData = await newsReq.json();
                            if (newsData && newsData.items && newsData.items.length > 0) {
                                const latestNews = newsData.items[0];
                                if (latestNews.content) {
                                    // Strip simple HTML tags from content
                                    snippet = latestNews.content.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim() || snippet;
                                }
                                if (latestNews.title) {
                                    title = `${title}: ${latestNews.title}`;
                                }
                            }
                        }
                    } catch (err) {
                        // ignore and use fallback summary
                    }

                    return {
                        title: title,
                        url: `https://bills.parliament.uk/bills/${item.billId}`,
                        source: 'UK Parliament',
                        category: 'Parliamentary',
                        industry_tag: getIndustryTag(title + " " + snippet),
                        snippet: snippet.substring(0, 350) + (snippet.length > 350 ? '...' : ''),
                        image_url: null,
                        published_at: item.lastUpdated || new Date().toISOString()
                    };
                });

                const parlNews = await Promise.all(parlPromises);
                allArticles = allArticles.concat(parlNews);
            }
        } catch (e) {
            console.error("Failed fetching Parliamentary News:", e);
        }

        // 4. Save to Supabase using REST API and Service Role Key
        if (allArticles.length > 0 && env.SUPABASE_URL && env.SUPABASE_SERVICE_ROLE) {
            try {
                const insertUrl = `${env.SUPABASE_URL}/rest/v1/news_articles?on_conflict=url`;

                const response = await fetch(insertUrl, {
                    method: 'POST',
                    headers: {
                        'apikey': env.SUPABASE_SERVICE_ROLE,
                        'Authorization': `Bearer ${env.SUPABASE_SERVICE_ROLE}`,
                        'Content-Type': 'application/json',
                        'Prefer': 'resolution=merge-duplicates'
                    },
                    body: JSON.stringify(allArticles)
                });

                if (!response.ok) {
                    const errText = await response.text();
                    console.error("Supabase upsert failed:", errText);
                } else {
                    console.log(`Successfully stored ${allArticles.length} articles.`);
                }
            } catch (e) {
                console.error("Supabase connection error:", e);
            }
        }
    }
};
