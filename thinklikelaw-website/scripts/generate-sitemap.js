const fs = require('fs');
const path = require('path');

const DOMAIN = 'https://www.thinklikelaw.com';
const websiteDir = path.join(__dirname, '..');
const blogDir = path.join(websiteDir, 'blog');

function generateSitemap() {
    const urls = [];

    // 1. Root HTML files
    const rootFiles = fs.readdirSync(websiteDir).filter(f => f.endsWith('.html'));
    for (const file of rootFiles) {
        if (file === 'blog-template.html') continue;
        const url = file === 'index.html' ? DOMAIN + '/' : DOMAIN + '/' + file;
        const priority = file === 'index.html' ? '1.0' : '0.8';
        urls.push({
            loc: url,
            lastmod: new Date().toISOString().split('T')[0],
            priority
        });
    }

    // 2. Blog files
    if (fs.existsSync(blogDir)) {
        const blogFiles = fs.readdirSync(blogDir).filter(f => f.endsWith('.html'));
        for (const file of blogFiles) {
            const url = DOMAIN + '/blog/' + file;
            const priority = file === 'index.html' ? '0.9' : '0.7';
            urls.push({
                loc: url,
                lastmod: new Date().toISOString().split('T')[0],
                priority
            });
        }
    }

    let xml = `<?xml version="1.0" encoding="UTF-8"?>\n`;
    xml += `<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n`;
    
    for (const item of urls) {
        xml += `  <url>\n`;
        xml += `    <loc>${item.loc}</loc>\n`;
        xml += `    <lastmod>${item.lastmod}</lastmod>\n`;
        xml += `    <priority>${item.priority}</priority>\n`;
        xml += `  </url>\n`;
    }
    
    xml += `</urlset>`;

    fs.writeFileSync(path.join(websiteDir, 'sitemap.xml'), xml);
    console.log('Sitemap generated successfully! Total URLs:', urls.length);
}

generateSitemap();
