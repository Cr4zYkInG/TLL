const fs = require('fs');
const path = require('path');

const BLOG_DIR = path.join(__dirname, '../blog');
const TEMPLATE_PATH = path.join(__dirname, '../blog-template.html');
const HUB_PATH = path.join(BLOG_DIR, 'index.html');

// Create blog dir if missing
if (!fs.existsSync(BLOG_DIR)) fs.mkdirSync(BLOG_DIR);

const competitors = ['Notion', 'Evernote', 'OneNote', 'Google Docs', 'Roam Research', 'Obsidian', 'Quizlet', 'Anki', 'MarginNote', 'NotebookLLM'];
const laws = ['Contract Law', 'Criminal Law', 'Tort Law', 'Public Law', 'Land Law', 'Equity & Trusts', 'EU Law', 'Jurisprudence', 'Company Law', 'Evidence Law', 'Commercial Law', 'Family Law', 'Intellectual Property Law', 'Human Rights Law', 'Medical Law', 'Employment Law'];

const actionVerbs = ['Master', 'Ace', 'Understand', 'Dominating', 'Survive', 'Thrive in', 'Break down', 'Conquer', 'Crush', 'Demystify'];

let blogs = [];

const actions = ['Mastering', 'Dominating', 'Understanding', 'Acing', 'Surviving', 'Revolutionizing', 'Conquering', 'Demystifying'];

function getComparisonContent(c) {
    return `
        <div class="blog-seo-summary">
            <strong>Executive Summary:</strong> Generic tools like ${c} lack the specialized legal AI architecture required for OSCOLA compliance, IRAC analysis, and automated case brief generation. ThinkLikeLaw provides a purpose-built ecosystem that saves law students an average of 15 hours per week.
        </div>

        <h2>The Structural Gap: Why ${c} Fails Law Students</h2>
        <p>In the high-stakes world of LLB and SQE preparation, efficiency isn't just a luxury—it's a requirement. General productivity apps like <strong>${c}</strong> are designed for a broad audience, from engineers to novelists. However, the legal degree demand specific vertical tools that ${c} was never built to handle.</p>
        
        <p>The core issue lies in <em>contextual awareness</em>. When you paste a judgment into ${c}, it treats it as plain text. When you paste it into ThinkLikeLaw, our legal-native models identify the Ratio Decidendi, distinguish between Obiter Dicta, and cross-reference relevant statutes automatically.</p>

        <div class="pro-tip">
            <span class="pro-tip-label">Case Study: R v Brown [1993]</span>
            In a generic tool like ${c}, searching for "consent" might return hundreds of unrelated notes. In ThinkLikeLaw, the AI clusters cases by legal principle, ensuring that when you're studying Non-Fatal Offences, the relevant precedents are always surfaced in your sidebar via the 'Legal Weaponry' feature.
        </div>

        <h2>Comprehensive Feature Matrix: ThinkLikeLaw vs ${c}</h2>
        <table class="comparison-table">
            <tr><th>Capability</th><th>ThinkLikeLaw</th><th>${c}</th></tr>
            <tr><td><strong>OSCOLA Referencing</strong></td><td>Native 1-click citation generating</td><td>Manual formatting or third-party plugins</td></tr>
            <tr><td><strong>Legal Issue Spotter</strong></td><td>AI identifies actionable issues in fact patterns</td><td>Non-existent (Generic text only)</td></tr>
            <tr><td><strong>Case Briefing</strong></td><td>Automated 3-point summaries (Facts/Ratio/Obiter)</td><td>Requires manual summarizing</td></tr>
            <tr><td><strong>Jurisdictional Guardrails</strong></td><td>Strict adherence to England & Wales Law</td><td>Hallucinates US/International precedents</td></tr>
        </table>

        <h2>The Cost of Inaction: The "Setup Tax"</h2>
        <p>Every hour you spend "setting up" your workspace in ${c} is an hour you aren't actually learning the law. Professional law students need an environment that is "batteries-included." ThinkLikeLaw's pre-structured modules mean you can start Case Mapping from day one, without wasting a single second on template design.</p>

        <h2>Frequently Asked Questions</h2>
        <div class="faq-section">
            <p><strong>Q: Can I import my existing ${c} notes?</strong><br>A: Yes, ThinkLikeLaw supports clean markdown imports, allowing you to upgrade your legacy notes into our legal-aware ecosystem instantly.</p>
            <p><strong>Q: Is ThinkLikeLaw's AI better than current LLMs in ${c}?</strong><br>A: Yes. While ${c} uses generic LLMs, our 'Scholar' and 'Examiner' personas are specifically fine-tuned on UK case law to ensure academic precision.</p>
        </div>

        <div class="action-checklist">
            <h3>Checklist: Time to Move?</h3>
            <ul>
                <li>[ ] Are you spending >20% of your time on "organising" rather than studying?</li>
                <li>[ ] Do you find yourself manually checking OSCOLA citations?</li>
                <li>[ ] Are your case summaries scattered across multiple pages?</li>
                <li>[ ] <strong>If you checked even one, it's time to switch.</strong></li>
            </ul>
        </div>
    `;
}

function getStudyGuideContent(law, verb) {
    return `
        <div class="blog-seo-summary">
            <strong>Executive Summary:</strong> Mastering ${law} requires more than just reading textbooks. This guide explores the IRAC frameworks, critical case law, and AI-driven study techniques needed to secure a First-Class grade in your ${law} exams.
        </div>

        <h2>The Foundation of ${law}</h2>
        <p>${law} is often considered one of the most challenging modules in the LLB/LNAT journey. The key is to move from passive reading to active <em>legal engineering</em>. You aren't just learning rules; you are learning how to apply tools (statutes) to problems (facts).</p>

        <h2>Strategic Case Analysis: Quality over Quantity</h2>
        <p>Students often make the mistake of memorizing every case mentioned in the lecture. For a First-Class answer in ${law}, you need a deep understanding of the <em>Ratio Decidendi</em> of the "Big Five" cases in each sub-topic, rather than a surface-level grasp of fifty.</p>
        
        <table>
            <tr><th>Topic</th><th>Leading Precedent</th><th>Key Takeaway</th></tr>
            <tr><td>Formation/Context</td><td>Case 1 Citation Needed</td><td>Fundamental Principle established</td></tr>
            <tr><td>Modern Interpretation</td><td>Case 2 Citation Needed</td><td>How the law adapted to the digital era</td></tr>
        </table>

        <div class="pro-tip">
            <span class="pro-tip-label">EXAMINER INSIGHT</span>
            Don't just state the law. Critique it. Does the current state of ${law} balance the interests of the parties fairly? Higher marks are awarded for identifying inconsistencies in judicial reasoning.
        </div>

        <h2>Implementing the ThinkLikeLaw Workflow</h2>
        <p>With ThinkLikeLaw, you can automate the 'Rule' section of your IRAC practice. Use our **OSCOLA Assistant** to ensure your citations are flawless, and use **Scholar Mode** to generate exhaustive notes that highlight the critical academic commentary—the difference between a 2:1 and a First.</p>

        <h2>FAQ: Common Pitfalls in ${law}</h2>
        <p><strong>What is the most common mistake in exam answers?</strong><br>Identifying the issues but failing to apply the rules to the specific facts of the scenario. Use our 'Issue Spotter' to practice this daily.</p>
        <p><strong>How many cases do I really need per essay?</strong><br>Aim for quality. Three deeply analyzed cases with critical commentary are better than ten citations with no analysis.</p>

        <div class="action-checklist">
            <h3>Your First-Class ${law} Checklist</h3>
            <ul>
                <li>[ ] Map out the hierarchical structure of key statutes.</li>
                <li>[ ] Create IRAC templates for the Top 20 most likely exam scenarios.</li>
                <li>[ ] Use ThinkLikeLaw to generate 5 active-recall flashcards for every core judgment.</li>
                <li>[ ] Conduct a "Critical Review" of one recent Law Commission report in this area.</li>
            </ul>
        </div>
    `;
}

function getAILegalContent(topic) {
    return `
        <div class="blog-seo-summary">
            <strong>Executive Summary:</strong> The legal industry is being disrupted at a fundamental level. Understanding how to leverage AI like ThinkLikeLaw is becoming a core competency for future solicitors and barristers.
        </div>

        <h2>${topic}: A Paradigm Shift</h2>
        <p>The legal profession is notoriously traditional, but 2026-27 has seen an unprecedented explosion in "Legal Tech." For students, this isn't just about saving time; it's about shifting the cognitive load. By allowing AI to handle the "low-value" tasks—like formatting citations or summarizing facts—students can focus on "high-value" tasks: critical analysis and legal strategy.</p>

        <h2>The Ethics of AI in Legal Studies</h2>
        <p>A common concern is whether using AI is "cheating." The distinction is clear: using AI to write your essay is plagiarism. Using AI as a <em>tutor</em>—to explain complex concepts, to spot issues you've missed, and to drill yourself on case law—is the hallmark of a technologically competent modern lawyer.</p>

        <div class="pro-tip">
            <span class="pro-tip-label">CAREER TIP</span>
            Magic Circle firms are now testing for "Legal AI Literacy" during assessment centers. Being able to explain how you used ThinkLikeLaw to streamline your degree shows a forward-thinking mindset that recruiters love.
        </div>

        <h2>FAQ: The Future of Law</h2>
        <p><strong>Will AI replace lawyers?</strong><br>No, but lawyers who use AI will replace lawyers who don't. The same applies to law students.</p>
        <p><strong>How do I cite AI research?</strong><br>Always primary source your findings. Use AI to find the case, then read the case itself to verify. ThinkLikeLaw's 'Double Check' feature makes this seamless.</p>

        <div class="action-checklist">
            <h3>Future-Ready Student Checklist</h3>
            <ul>
                <li>[ ] Familiarize yourself with Prompt Engineering for Legal scenarios.</li>
                <li>[ ] Learn to identify AI hallucinations in legal citations.</li>
                <li>[ ] Build a "Digital Brain" in ThinkLikeLaw to store your long-term legal knowledge.</li>
            </ul>
        </div>
    `;
}

function generateBlogs() {
    let id = 1;

    // 20 Competitor Comparisons
    for (let c of competitors) {
        blogs.push({
            title: `ThinkLikeLaw vs ${c}: The Ultimate AI Tool for Law Students`,
            slug: `thinklikelaw-vs-${c.toLowerCase().replace(/ /g, '-')}-for-law-students`,
            category: 'Comparisons',
            readTime: 12,
            date: `Oct ${id % 28 + 1}, 2026`,
            excerpt: `Stop using generic tools for a specific degree. See why thousands of LLB students are migrating from ${c} to our purpose-built legal AI ecosystem.`,
            content: getComparisonContent(c),
            image: `bg-${(id % 3) + 1}.jpg`
        });
        id++;
        
        blogs.push({
            title: `Why ${c} is Holding Back Your Law Degree in 2027`,
            slug: `why-${c.toLowerCase().replace(/ /g, '-')}-is-bad-for-law-students`,
            category: 'Workflow Guide',
            readTime: 10,
            date: `Nov ${id % 28 + 1}, 2026`,
            excerpt: `Generic productivity apps like ${c} carry a hidden "Setup Tax." Learn how to reclaim 10+ hours a week by switching to a pre-structured Law environment.`,
            content: getComparisonContent(c), // Reuse comparison logic for depth
            image: `bg-${(id % 3) + 1}.jpg`
        });
        id++;
    }

    // 20 Law Module Guides
    for (let law of laws) {
        let verb = actions[id % actions.length];
        blogs.push({
            title: `${verb} ${law} in First Class: The Definitive AI Framework`,
            slug: `${verb.toLowerCase()}-${law.toLowerCase().replace(/ /g, '-').replace(/&/g, 'and')}-guide`,
            category: 'Study Strategies',
            readTime: 15,
            date: `Dec ${id % 28 + 1}, 2026`,
            excerpt: `How to get a First in ${law} without burning out. A comprehensive deep-dive into IRAC application, critical commentary, and AI-driven case mapping.`,
            content: getStudyGuideContent(law, verb),
            image: `bg-${(id % 3) + 1}.jpg`
        });
        id++;
    }

    // 30 AI SEO Topics
    const seoTopics = [
        "How ChatGPT is Changing Law School Forever", "The Future of Legal Tech in Education", 
        "Why Traditional Note-Taking is Dead in 2027", "Best AI Flashcard Makers for Law Students", 
        "How to Write an OSCOLA Essay in Half the Time", "Understanding the SQE with AI Tools", 
        "Law School Burnout: How AI Reduces Stress", "First Year LLB Survival Guide 2026", 
        "A-Level Law vs LLB: What to expect", "How to prepare for a Training Contract Interview with AI",
        "The Ethics of AI in Legal Studies", "Can AI Write My Law Essay? (A Warning)", 
        "How to Use NotebookLLM for Legal Cases", "ThinkLikeLaw Features That Will blow your mind",
        "Top 5 AI Chrome Extensions for Law Students", "How to summarize 100 pages of readings in 10 minutes",
        "Why You Still Need Textbooks in the AI Era", "IRAC vs CLEO: Best answering methods", 
        "How Magic Circle Firms View AI Experience", "The Ultimate Pre-Read Guide for LNAT 2027",
        "Top AI Tools for Legal Research in 2026", "Does AI Plagiarism Detection Work for Law Essay?",
        "SQE1 Prep: Using AI to Master Multiple Choice", "How to Create an Automated Legal Dictionary",
        "From LLB to Trainee: The Ultimate Toolkit", "Best iPad Apps for Law Students in 2026",
        "How AI is Revolutionising Commercial Awareness", "Surviving Law School Exams with ThinkLikeLaw",
        "The Definitive Guide to OSCOLA Referencing", "Note-Taking Strategies for Core Law Modules"
    ];

    for (let t of seoTopics) {
         blogs.push({
            title: t,
            slug: t.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, ''),
            category: 'Legal AI Trends',
            readTime: 10,
            date: `Jan ${id % 28 + 1}, 2027`,
            excerpt: `Explore the cutting edge of legal education. From prompt engineering to AI-driven issue spotting, here is how the next generation of lawyers is being trained.`,
            content: getAILegalContent(t),
            image: `bg-${(id % 3) + 1}.jpg`
        });
        id++;
    }
}

generateBlogs();
console.log(`Generated ${blogs.length} blog records!`);

const templateObj = fs.readFileSync(TEMPLATE_PATH, 'utf8');

// Build Hub Page HTML
let hubHtml = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Law Student Hub & Resources | ThinkLikeLaw</title>
    <meta name="description" content="60+ guides, comparisons and tips to get a First Class in your LLB and ace your SQE/LPC.">
    <link rel="icon" type="image/x-icon" href="../images/logo-icon-final.png">
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="../style.css?v=3.0.0">
    <link rel="stylesheet" href="../landing.css?v=3.0.0">
    <style>
        .hub-header { padding: 12rem 2rem 6rem; text-align: center; max-width: 800px; margin: 0 auto; }
        .hub-title { font-size: 3.5rem; font-weight: 800; letter-spacing: -0.03em; margin-bottom: 1.5rem; color: var(--text-primary); }
        .hub-sub { font-size: 1.15rem; color: var(--text-secondary); line-height: 1.6; }
        .blog-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 2rem; padding: 2rem 5%; max-width: 1400px; margin: 0 auto 8rem; }
        .blog-card { background: var(--glass-bg); backdrop-filter: var(--blur-amount); -webkit-backdrop-filter: var(--blur-amount); border: var(--glass-border); border-radius: var(--radius-lg); padding: 2rem; text-decoration: none; display: flex; flex-direction: column; transition: var(--spring); box-shadow: var(--card-shadow); }
        .blog-card:hover { transform: translateY(-4px); box-shadow: var(--card-shadow-hover); border-color: var(--text-primary); background: var(--surface-solid, var(--surface-color)); }
        .bc-cat { font-size: 0.75rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-secondary); margin-bottom: 1rem; }
        .bc-title { font-size: 1.25rem; font-weight: 700; color: var(--text-primary); margin-bottom: 1rem; line-height: 1.4; }
        .bc-excerpt { font-size: 0.9rem; color: var(--text-secondary); line-height: 1.6; margin-bottom: 2rem; flex: 1; }
        .bc-meta { font-size: 0.8rem; color: var(--text-secondary); opacity: 0.7; font-weight: 500; }
    </style>
</head>
<body class="lp-body">
    <div class="scroll-progress" id="progress-bar"></div>
    <div class="early-access-banner">
        <span><i class="fas fa-gift"></i> Early Access: Credits are currently inflated to help you explore. Found a bug or have a feature wish? <a href="mailto:feedback@thinklikelaw.com">Let us know!</a></span>
    </div>
    <nav class="lp-nav" id="navbar">
        <div class="lp-nav-logo">
            <a href="../index.html"><img src="../images/logo-text-final.png" alt="ThinkLikeLaw" style="height:35px;"></a>
        </div>
        <ul class="lp-nav-links">
            <li><a href="/#features"><i class="fas fa-globe-europe"></i> Features</a></li>
            <li><a href="/blog/"><i class="fas fa-folder-open"></i> Resources</a></li>
            <li><a href="/#pricing"><i class="fas fa-tag"></i> Pricing</a></li>
            <li><a href="/support"><i class="fas fa-comment-dots"></i> Support</a></li>
            <li class="nav-control-group">
                <i class="fas fa-cat nav-mascot-icon" id="nav-mascot-trigger" title="Meet Ben"></i>
                <button class="nav-icon-btn" id="lp-theme-toggle" title="Toggle Theme">
                    <i class="fas fa-moon"></i>
                </button>
            </li>
            <li><a href="/login" class="nav-btn-outline">Sign In</a></li>
            <li><a href="/signup" class="nav-btn-primary">Join Free</a></li>
        </ul>
    </nav>
    <header class="hub-header">
        <h1 class="hub-title">The Legal Study Hub</h1>
        <p class="hub-sub">60+ in-depth guides, competitor comparisons, and study strategies to master your law degree. Find out exactly why modern law students are switching to specialized AI.</p>
    </header>
    <div class="blog-grid">
`;

// Write individual pages and append to hub
blogs.forEach((b, idx) => {
    // Pick 2 random related posts
    let relatedIndices = [];
    while(relatedIndices.length < 2) {
        let r = Math.floor(Math.random() * blogs.length);
        if(r !== idx && !relatedIndices.includes(r)) relatedIndices.push(r);
    }
    
    let relatedHtml = relatedIndices.map(ri => {
        let rb = blogs[ri];
        return `
            <a href="${rb.slug}" class="related-card">
                <div style="font-size:0.75rem;color:var(--text-secondary);text-transform:uppercase;margin-bottom:10px;font-weight:700;">${rb.category}</div>
                <h4 style="font-size:1.1rem;margin-bottom:10px;color:var(--text-primary);">${rb.title}</h4>
                <p style="font-size:0.85rem;color:var(--text-secondary);">${rb.excerpt.substring(0, 60)}...</p>
            </a>
        `;
    }).join('');

    let ht = templateObj
        .replace(/{{TITLE}}/g, b.title)
        .replace(/{{SLUG}}/g, b.slug)
        .replace(/{{CATEGORY}}/g, b.category)
        .replace(/{{DATE}}/g, b.date)
        .replace(/{{READ_TIME}}/g, b.readTime)
        .replace(/{{DESCRIPTION}}/g, b.excerpt)
        .replace(/{{CONTENT}}/g, b.content)
        .replace(/{{IMAGE}}/g, `bg-${(Math.floor(Math.random() * 3) + 1)}.jpg`)
        .replace(/{{RELATED_POSTS}}/g, relatedHtml);
    
    fs.writeFileSync(path.join(BLOG_DIR, `${b.slug}.html`), ht, 'utf8');

    hubHtml += `
        <a href="${b.slug}" class="blog-card">
            <span class="bc-cat">${b.category}</span>
            <h3 class="bc-title">${b.title}</h3>
            <p class="bc-excerpt">${b.excerpt}</p>
            <div class="bc-meta">${b.readTime} min read &bull; ${b.date}</div>
        </a>
    `;
});

hubHtml += `
    </div>
    <script src="../main.js?v=2.5.2"></script>
    <script>
        // Navbar Scroll Effect
        window.addEventListener('scroll', () => {
            const nav = document.querySelector('.lp-nav');
            if (window.scrollY > 50) {
                nav.classList.add('scrolled');
            } else {
                nav.classList.remove('scrolled');
            }
            const scrolled = window.scrollY;
            const height = document.documentElement.scrollHeight - window.innerHeight;
            const progress = (scrolled / height) * 100;
            const progressBar = document.getElementById('progress-bar');
            if (progressBar) progressBar.style.width = progress + '%';
        });
    </script>
</body>
</html>
`;

fs.writeFileSync(HUB_PATH, hubHtml, 'utf8');
console.log('Hub generated successfully!');
